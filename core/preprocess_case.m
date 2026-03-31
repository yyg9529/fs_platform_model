function caseDef = preprocess_case(caseDef)
%PREPROCESS_CASE 预处理 V1.0.4 案例并生成派生量。
% 功能说明:
%   1) 统一几何参数 lf/lr 与 wf_static 的一致性。
%   2) 计算角点几何矩阵、刚度矩阵与静态轮载。
%   3) 统一 shock eye-to-eye 输入并派生行程能力。
%   4) 新增 tire.mode 解析与 kt 场景派生。
%   5) 派生 shock↔wheel 一致性、effective travel 与 bumpAdjust 保守修正量。
%
% 输入:
%   caseDef - 通过 validate_case_struct 的输入结构体
%
% 输出:
%   caseDef - 增加 derived 字段后的结构体
%
% 关键物理假设:
%   1) 角点顺序固定 [FL FR RL RR]
%   2) off 模式使用 keq=kw；fixed/range(单场景) 使用串联 keq
%   3) shockLenExtended/shockLenCompressed 为规格参数，shockLenStatic 为静态安装设定
%
% 单位约定:
%   长度 [m]，力 [N]，力矩 [N*m]，角度 [rad]

veh = caseDef.veh;
sus = caseDef.sus;

% ===== 1) 处理 lf / lr / wf_static =====
lf = veh.lf;
lr = veh.lr;
L = veh.L;
wf = veh.wf_static;

if isempty(lf) && isempty(lr)
    lf = (1 - wf) * L;
    lr = wf * L;
elseif isempty(lf) && ~isempty(lr)
    lf = L - lr;
elseif ~isempty(lf) && isempty(lr)
    lr = L - lf;
end

if lf <= 0 || lr <= 0
    error('preprocess_case:BadWheelbaseSplit', 'Derived lf/lr must be > 0.');
end

sumLR = lf + lr;
if abs(sumLR - L) > 1e-9
    scale = L / sumLR;
    lf = lf * scale;
    lr = lr * scale;
end

wfFromGeo = lr / L;
if abs(wfFromGeo - wf) > 1e-4
    caseDef.meta.notes = sprintf('%s | wf_static adjusted to match lf/lr', caseDef.meta.notes);
    wf = wfFromGeo;
end

veh.lf = lf;
veh.lr = lr;
veh.wf_static = wf;

% hRA_CG = hRCf + (lf / L) * (hRCr - hRCf)
hRA_CG = veh.hRCf + (lf / L) * (veh.hRCr - veh.hRCf);

% ===== 2) 统一 shock 参数为 4 角点数组 =====
sus.shockLenExtended = expand_scalar_or_corner(sus.shockLenExtended, 'shockLenExtended');
sus.shockLenCompressed = expand_scalar_or_corner(sus.shockLenCompressed, 'shockLenCompressed');
sus.shockLenStatic = expand_scalar_or_corner(sus.shockLenStatic, 'shockLenStatic');

% ===== 3) shock 行程能力派生量 =====
shockStrokeTotal = sus.shockLenExtended - sus.shockLenCompressed;
shockStrokeStaticUsed = sus.shockLenExtended - sus.shockLenStatic;
shockCompAvail = sus.shockLenStatic - sus.shockLenCompressed;
shockReboundAvail = sus.shockLenExtended - sus.shockLenStatic;

if any(shockStrokeTotal <= 0)
    error('preprocess_case:BadShockStrokeTotal', 'shockStrokeTotal must be positive at every corner.');
end

% shock↔wheel 一致性派生量（这里是“由减振器能力折算到轮端”的可用容量，不是当前实际位移）
wheelJounceFromShock = shockCompAvail ./ max(sus.mr(:), eps);
wheelDroopFromShock = shockReboundAvail ./ max(sus.mr(:), eps);
effectiveJounce = min(sus.jounceMax(:), wheelJounceFromShock);
effectiveDroop = min(sus.droopMax(:), wheelDroopFromShock);
effectiveTotalTravel = effectiveJounce + effectiveDroop;

jounceDiff = abs(wheelJounceFromShock - sus.jounceMax(:));
droopDiff = abs(wheelDroopFromShock - sus.droopMax(:));
jounceTol = max(2e-3, 0.20 * max(sus.jounceMax(:), eps));
droopTol = max(2e-3, 0.20 * max(sus.droopMax(:), eps));
shockWheelConsistencyWarning = any(jounceDiff > jounceTol) || any(droopDiff > droopTol);

% ===== 4) 角点几何与主平衡刚度 =====
geom = build_corner_geometry(veh);

tireDerived = resolve_tire_derived(caseDef);
stiff = build_stiffness_matrix(sus, geom, tireDerived);

% 将自动计算的 kw 回写到 sus，便于结果追踪
sus.kw = stiff.kw;

% ===== 5) 静态角点法向载荷 =====
Fz_f0 = veh.m * veh.g * veh.wf_static / 2;
Fz_r0 = veh.m * veh.g * (1 - veh.wf_static) / 2;
FzStatic = [Fz_f0; Fz_f0; Fz_r0; Fz_r0];

% ===== 6) bump-adjusted clearance 保守修正输入 =====
bumpDerived = build_bump_adjust_derived(caseDef.bumpAdjust, caseDef.ref.xClear(:));

caseDef.veh = veh;
caseDef.sus = sus;

caseDef.derived = struct();
caseDef.derived.hRA_CG = hRA_CG;
caseDef.derived.geom = geom;
caseDef.derived.stiff = stiff;
caseDef.derived.FzStatic = FzStatic;
caseDef.derived.cornerNames = geom.names;
caseDef.derived.tire = tireDerived;
caseDef.derived.bumpAdjust = bumpDerived;

caseDef.derived.susp = struct();
caseDef.derived.susp.shockLenExtended = sus.shockLenExtended;
caseDef.derived.susp.shockLenCompressed = sus.shockLenCompressed;
caseDef.derived.susp.shockLenStatic = sus.shockLenStatic;
caseDef.derived.susp.shockStrokeTotal = shockStrokeTotal;
caseDef.derived.susp.shockStrokeStaticUsed = shockStrokeStaticUsed;
caseDef.derived.susp.shockCompAvail = shockCompAvail;
caseDef.derived.susp.shockReboundAvail = shockReboundAvail;
caseDef.derived.susp.wheelJounceFromShock = wheelJounceFromShock;
caseDef.derived.susp.wheelDroopFromShock = wheelDroopFromShock;
caseDef.derived.susp.effectiveJounce = effectiveJounce;
caseDef.derived.susp.effectiveDroop = effectiveDroop;
caseDef.derived.susp.effectiveTotalTravel = effectiveTotalTravel;
caseDef.derived.susp.shockWheelConsistencyWarning = shockWheelConsistencyWarning;
end

function bumpDerived = build_bump_adjust_derived(bumpAdjust, xClear)
%BUILD_BUMP_ADJUST_DERIVED 生成 bump 保守修正的按点预留量。
reserveFront = double(bumpAdjust.reserveFront);
reserveRear = double(bumpAdjust.reserveRear);
frontMask = xClear > 0;
rearMask = xClear < 0;
centerMask = ~(frontMask | rearMask);

reserveByPoint = zeros(size(xClear));
if logical(bumpAdjust.enable)
    reserveByPoint(frontMask) = reserveFront;
    reserveByPoint(rearMask) = reserveRear;
    reserveByPoint(centerMask) = max(reserveFront, reserveRear);
end

bumpDerived = struct();
bumpDerived.enable = logical(bumpAdjust.enable);
bumpDerived.reserveFront = reserveFront;
bumpDerived.reserveRear = reserveRear;
bumpDerived.frontMask = frontMask;
bumpDerived.rearMask = rearMask;
bumpDerived.centerMask = centerMask;
bumpDerived.reserveByPoint = reserveByPoint;
end

function tireDerived = resolve_tire_derived(caseDef)
%RESOLVE_TIRE_DERIVED 解析 tire.mode 并生成求解所需轮胎刚度场景。
modeStr = lower(strtrim(char(string(caseDef.tire.mode))));

tireDerived = struct();
tireDerived.mode = modeStr;
tireDerived.tireComplianceIgnored = strcmp(modeStr, 'off');
tireDerived.ktUsed = inf(4,1);
tireDerived.ktCaseLabel = 'off';
tireDerived.ktBand = nan(1,3);

switch modeStr
    case 'off'
        tireDerived.ktCaseLabel = 'off';
        tireDerived.ktBand = nan(1,3);

    case 'fixed'
        % 当前正式接口优先使用 tire.*。
        % sus.kt 仅保留旧 case 兼容 fallback，且只有在非空时才允许承接。
        fallbackFront = [];
        fallbackRear = [];
        if isfield(caseDef.sus, 'kt') && ~isempty(caseDef.sus.kt)
            fallbackFront = caseDef.sus.kt(1:2);
            fallbackRear = caseDef.sus.kt(3:4);
        end
        ktFrontPair = normalize_side_pair(caseDef.tire.ktFront, fallbackFront, 'front');
        ktRearPair = normalize_side_pair(caseDef.tire.ktRear, fallbackRear, 'rear');
        tireDerived.ktUsed = [ktFrontPair(:); ktRearPair(:)];
        tireDerived.ktCaseLabel = 'fixed';
        ktAvg = mean(tireDerived.ktUsed);
        tireDerived.ktBand = [ktAvg, ktAvg, ktAvg];

    case 'range'
        fRange = normalize_triplet(caseDef.tire.ktFrontRange);
        rRange = normalize_triplet(caseDef.tire.ktRearRange);
        tireDerived.ktUsed = [fRange(2); fRange(2); rRange(2); rRange(2)];
        tireDerived.ktCaseLabel = 'nominal';
        tireDerived.ktBand = [mean([fRange(1), rRange(1)]), mean([fRange(2), rRange(2)]), mean([fRange(3), rRange(3)])];

    otherwise
        error('preprocess_case:BadTireMode', 'Unsupported tire.mode: %s', modeStr);
end
end

function vec4 = expand_scalar_or_corner(x, fieldName)
if ~isnumeric(x) || isempty(x)
    error('preprocess_case:MissingField', 'caseDef.sus.%s must be scalar or 4-element numeric.', fieldName);
end

if isscalar(x)
    vec4 = repmat(double(x), 4, 1);
elseif numel(x) == 4
    vec4 = double(x(:));
else
    error('preprocess_case:BadSize', 'caseDef.sus.%s must be scalar or 4-element numeric.', fieldName);
end
end

function pair = normalize_side_pair(x, fallbackPair, sideTag)
%NORMALIZE_SIDE_PAIR front/rear 侧输入归一为 [2x1]。
if isempty(x)
    if isempty(fallbackPair)
        error('preprocess_case:MissingTireKt', 'Missing %s tire kt and no valid fallback.', sideTag);
    end
    x = fallbackPair;
end
if ~isnumeric(x)
    error('preprocess_case:BadTireKt', '%s tire kt must be numeric.', sideTag);
end

x = double(x(:));
switch numel(x)
    case 1
        pair = [x; x];
    case 2
        pair = x;
    case 4
        if strcmpi(sideTag, 'front')
            pair = x(1:2);
        else
            pair = x(3:4);
        end
    otherwise
        error('preprocess_case:BadTireKtSize', '%s tire kt must be scalar, [2x1], or [4x1].', sideTag);
end

if any(~isfinite(pair)) || any(pair <= 0)
    error('preprocess_case:BadTireKtValue', '%s tire kt must contain finite positive values.', sideTag);
end
end

function trip = normalize_triplet(x)
if isempty(x) || ~isnumeric(x)
    error('preprocess_case:BadTireRange', 'tire range must be numeric with 2 or 3 elements.');
end
x = sort(double(x(:)), 'ascend');
if numel(x) == 2
    trip = [x(1); 0.5 * (x(1) + x(2)); x(2)];
elseif numel(x) == 3
    trip = x;
else
    error('preprocess_case:BadTireRangeSize', 'tire range must have 2 or 3 elements.');
end
if any(~isfinite(trip)) || any(trip <= 0)
    error('preprocess_case:BadTireRangeValue', 'tire range values must be finite and positive.');
end
end
