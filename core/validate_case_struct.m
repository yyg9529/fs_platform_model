function [caseDef, report] = validate_case_struct(caseDef)
%VALIDATE_CASE_STRUCT 校验并规范化 V1.5 的 caseDef 输入结构。
% 功能说明:
%   1) 校验 caseDef 的必需字段、尺寸和数值范围。
%   2) 对角点字段做规范化（顺序固定 [FL FR RL RR]）。
%   3) 校验 shock eye-to-eye 输入与物理关系。
%   4) 新增 tire.forceModel / tireOp / rules / targets / bumpAdjust 输入层检查。
%   5) 对 deprecated 字段给出显式 warning（不再静默使用）。
%   6) 保留 autofill / deprecated / consistency warning 机制，
%      但标准 case 的目标应是“正常运行时不依赖这些 warning 才成立”。
%
% 输入:
%   caseDef - 用户输入结构体
%
% 输出:
%   caseDef - 规范化后的结构体
%   report  - 校验报告（badInput/messages/warnings/filled/一致性检查）
%
% 关键物理假设:
%   1) 模型定位维持三自由度准静态平台
%   2) bump/droop 附加力不参与主平衡
%   3) 轮胎柔度通过 tire.mode 管理，不再隐式假设唯一 kt
%
% 单位约定:
%   全部采用 SI（m, kg, N, rad, m/s, m/s^2）

if nargin < 1 || ~isstruct(caseDef) || ~isscalar(caseDef)
    error('validate_case_struct:BadInput', 'caseDef must be a scalar struct.');
end

defaults = local_default_case();
shapeMessages = validate_struct_shape(caseDef, defaults, 'caseDef');
if ~isempty(shapeMessages)
    error('validate_case_struct:BadNestedStruct', '%s', strjoin(shapeMessages, ' | '));
end
[caseDef, filled] = ensure_fields(caseDef, defaults, true);
filledForWarning = filter_reportable_autofill_fields(filled);

report = struct();
report.badInput = false;
report.messages = {};
report.warnings = {};
report.filled = filled;
report.filledForWarning = filledForWarning;
report.wheelJounceFromShock = nan(4,1);
report.wheelDroopFromShock = nan(4,1);
report.shockWheelConsistencyWarning = false;

% autofill warning 的工程意义：
%   1) 暴露“当前输入是否依赖 validate/local_default_case 才能成立”
%   2) 帮助旧 case 迁移到当前正式接口
% 但对兼容层专用的空默认字段（如 sus.kt、旧 bump/droop 占位），
% 不再把它们计入标准 case 的 autofill warning，以免噪声掩盖真正的输入缺口。
if ~isempty(filledForWarning)
    report.warnings{end+1, 1} = sprintf('Auto-filled missing fields: %d', numel(filledForWarning));
end

% ===== 顶层字段检查 =====
topReq = {'meta','veh','sus','tire','tireOp','rules','targets','bumpAdjust','longi','aero','ref','man','solver'};
for i = 1:numel(topReq)
    if ~isfield(caseDef, topReq{i})
        report.messages{end+1, 1} = sprintf('Missing top-level field caseDef.%s', topReq{i});
    end
end

% ===== 车辆基础范围检查 =====
vehMustScalar = {'m','g','L','wf_static','tf','tr','hCG','hRCf','hRCr'};
for i = 1:numel(vehMustScalar)
    fn = vehMustScalar{i};
    if ~is_finite_scalar(caseDef.veh.(fn))
        report.messages{end+1, 1} = sprintf('caseDef.veh.%s must be finite numeric scalar.', fn);
    end
end
if is_finite_scalar(caseDef.veh.m) && caseDef.veh.m <= 0; report.messages{end+1, 1} = 'caseDef.veh.m must be > 0.'; end
if is_finite_scalar(caseDef.veh.g) && caseDef.veh.g <= 0; report.messages{end+1, 1} = 'caseDef.veh.g must be > 0.'; end
if is_finite_scalar(caseDef.veh.L) && caseDef.veh.L <= 0; report.messages{end+1, 1} = 'caseDef.veh.L must be > 0.'; end
if is_finite_scalar(caseDef.veh.tf) && caseDef.veh.tf <= 0; report.messages{end+1, 1} = 'caseDef.veh.tf must be > 0.'; end
if is_finite_scalar(caseDef.veh.tr) && caseDef.veh.tr <= 0; report.messages{end+1, 1} = 'caseDef.veh.tr must be > 0.'; end
if is_finite_scalar(caseDef.veh.hCG) && caseDef.veh.hCG < 0; report.messages{end+1, 1} = 'caseDef.veh.hCG must be >= 0.'; end
if is_finite_scalar(caseDef.veh.wf_static) && ...
        (caseDef.veh.wf_static <= 0 || caseDef.veh.wf_static >= 1)
    report.messages{end+1, 1} = 'caseDef.veh.wf_static must be in (0,1).';
end

axleFields = {'lf','lr'};
for i = 1:numel(axleFields)
    fn = axleFields{i};
    value = caseDef.veh.(fn);
    if ~isempty(value) && (~is_finite_scalar(value) || value <= 0)
        report.messages{end+1, 1} = sprintf( ...
            'caseDef.veh.%s must be empty or a finite positive scalar.', fn);
    end
end
lfValid = is_finite_scalar(caseDef.veh.lf) && caseDef.veh.lf > 0;
lrValid = is_finite_scalar(caseDef.veh.lr) && caseDef.veh.lr > 0;
LValid = is_finite_scalar(caseDef.veh.L) && caseDef.veh.L > 0;
if LValid && lfValid && lrValid
    splitTol = max(1e-9, 1e-6 * caseDef.veh.L);
    if abs(caseDef.veh.lf + caseDef.veh.lr - caseDef.veh.L) > splitTol
        report.messages{end+1, 1} = 'caseDef.veh.lf + caseDef.veh.lr must equal caseDef.veh.L.';
    end
elseif LValid && lfValid && caseDef.veh.lf >= caseDef.veh.L
    report.messages{end+1, 1} = 'caseDef.veh.lf must be less than caseDef.veh.L when lr is omitted.';
elseif LValid && lrValid && caseDef.veh.lr >= caseDef.veh.L
    report.messages{end+1, 1} = 'caseDef.veh.lr must be less than caseDef.veh.L when lf is omitted.';
end

% ===== 必要角点字段规范化为 [4x1] =====
requiredCornerFields = {'ks','mr','jounceMax','droopMax'};
for i = 1:numel(requiredCornerFields)
    fn = requiredCornerFields{i};
    [vec, ok, msg] = normalize_corner_vector(caseDef.sus.(fn), fn);
    if ok
        caseDef.sus.(fn) = vec;
    else
        report.messages{end+1, 1} = msg;
    end
end

% kw 可空；非空时按角点向量处理
if isempty(caseDef.sus.kw)
    % 留空表示后续按 kw = ks * mr^2 自动计算
elseif isnumeric(caseDef.sus.kw)
    [vec, ok, msg] = normalize_corner_vector(caseDef.sus.kw, 'kw');
    if ok
        caseDef.sus.kw = vec;
        kwFromSpring = caseDef.sus.ks .* (caseDef.sus.mr .^ 2);
        kwScale = max(abs(kwFromSpring), 1.0);
        if any(abs(vec - kwFromSpring) ./ kwScale > 1e-8)
            report.messages{end+1, 1} = [ ...
                'caseDef.sus.kw conflicts with ks.*mr.^2. Leave kw empty for automatic ', ...
                'derivation or provide a consistent legacy value.'];
        end
    else
        report.messages{end+1, 1} = msg;
    end
else
    report.messages{end+1, 1} = 'caseDef.sus.kw must be numeric [4x1] or empty.';
end

% sus.kt 为 deprecated：兼容读取，不作为当前正式轮胎输入字段。
% 标准 case 应显式使用 tire.mode / tire.ktFront / tire.ktRear / tire.kt*Range。
if isempty(caseDef.sus.kt)
    % 允许为空
elseif isnumeric(caseDef.sus.kt)
    [vec, ok, msg] = normalize_corner_vector(caseDef.sus.kt, 'kt');
    if ok
        caseDef.sus.kt = vec;
        report.warnings{end+1, 1} = 'caseDef.sus.kt is deprecated; use caseDef.tire.* in V1.5.';
    else
        report.messages{end+1, 1} = msg;
    end
else
    report.messages{end+1, 1} = 'caseDef.sus.kt must be numeric [4x1], scalar, or empty.';
end

if ~is_finite_scalar(caseDef.sus.kArbF) || ~is_finite_scalar(caseDef.sus.kArbR)
    report.messages{end+1, 1} = 'caseDef.sus.kArbF/kArbR must be finite scalar.';
elseif caseDef.sus.kArbF < 0 || caseDef.sus.kArbR < 0
    report.messages{end+1, 1} = 'caseDef.sus.kArbF/kArbR must be >= 0.';
end

% ===== deprecated 字段兼容警告（不参与主求解） =====
deprecatedFields = {'kBump','bumpGap','kDroop','droopGap'};
for i = 1:numel(deprecatedFields)
    fn = deprecatedFields{i};
    if isfield(caseDef.sus, fn) && ~isempty(caseDef.sus.(fn))
        report.warnings{end+1, 1} = sprintf('caseDef.sus.%s is deprecated and ignored in V1.5 main solve.', fn);
    end
end

% ===== shock eye-to-eye 输入检查：允许标量或 4 元数组 =====
[shockExt, okExt, msgExt] = validate_scalar_or_corner(caseDef.sus.shockLenExtended, 'shockLenExtended');
if ~okExt; report.messages{end+1, 1} = msgExt; else; caseDef.sus.shockLenExtended = shockExt; end
[shockCmp, okCmp, msgCmp] = validate_scalar_or_corner(caseDef.sus.shockLenCompressed, 'shockLenCompressed');
if ~okCmp; report.messages{end+1, 1} = msgCmp; else; caseDef.sus.shockLenCompressed = shockCmp; end
[shockSta, okSta, msgSta] = validate_scalar_or_corner(caseDef.sus.shockLenStatic, 'shockLenStatic');
if ~okSta; report.messages{end+1, 1} = msgSta; else; caseDef.sus.shockLenStatic = shockSta; end

if okExt && okCmp && okSta
    ext4 = expand_scalar_or_corner(caseDef.sus.shockLenExtended);
    cmp4 = expand_scalar_or_corner(caseDef.sus.shockLenCompressed);
    sta4 = expand_scalar_or_corner(caseDef.sus.shockLenStatic);

    if any(~(ext4 > sta4 & sta4 > cmp4))
        report.messages{end+1, 1} = ...
            'Each corner must satisfy shockLenExtended > shockLenStatic > shockLenCompressed.';
    end

    if any((ext4 - cmp4) <= 0)
        report.messages{end+1, 1} = ...
            'Each corner must satisfy shockLenExtended - shockLenCompressed > 0.';
    end

    % shock 与 wheel 限制一致性检查（提前暴露输入层矛盾）
    if all(isfinite(caseDef.sus.mr)) && all(caseDef.sus.mr > 0)
        shockCompAvail = sta4 - cmp4;
        shockReboundAvail = ext4 - sta4;
        report.wheelJounceFromShock = shockCompAvail ./ caseDef.sus.mr(:);
        report.wheelDroopFromShock = shockReboundAvail ./ caseDef.sus.mr(:);

        jounceDiff = abs(report.wheelJounceFromShock - caseDef.sus.jounceMax(:));
        droopDiff = abs(report.wheelDroopFromShock - caseDef.sus.droopMax(:));
        jounceTol = max(2e-3, 0.20 * max(caseDef.sus.jounceMax(:), eps));
        droopTol = max(2e-3, 0.20 * max(caseDef.sus.droopMax(:), eps));
        report.shockWheelConsistencyWarning = any(jounceDiff > jounceTol) || any(droopDiff > droopTol);

        if report.shockWheelConsistencyWarning
            report.warnings{end+1, 1} = [ ...
                'Shock-based wheel travel capacity differs significantly from jounceMax/droopMax. ', ...
                'Rule checks will use effective travel = min(wheel limit, shock-derived capacity). ', ...
                'Please check mechanical consistency.' ...
            ];
        end
    end
end

% ===== tire.mode 检查 =====
[modeOk, modeStr] = local_validate_enum_string(caseDef.tire.mode, {'off','fixed','range'});
if ~modeOk
    report.messages{end+1, 1} = 'caseDef.tire.mode must be ''off'', ''fixed'', or ''range''.';
end
caseDef.tire.mode = modeStr;

[forceMsgs, forceWarns, caseDef] = local_validate_tire_force_model(caseDef);
report.messages = [report.messages; forceMsgs(:)];
report.warnings = [report.warnings; forceWarns(:)];

[tireKtFront, okFront, msgFront] = normalize_axle_or_corner(caseDef.tire.ktFront, 'tire.ktFront', true);
if ~okFront
    report.messages{end+1,1} = msgFront;
end
[tireKtRear, okRear, msgRear] = normalize_axle_or_corner(caseDef.tire.ktRear, 'tire.ktRear', true);
if ~okRear
    report.messages{end+1,1} = msgRear;
end

switch modeStr
    case 'off'
        % off 模式允许 kt 为空或给值；给值也不参与主平衡。
    case 'fixed'
        if isempty(tireKtFront) || isempty(tireKtRear)
            % 允许从 deprecated sus.kt 自动承接一次，避免中断旧脚本
            if ~isempty(caseDef.sus.kt)
                caseDef.tire.ktFront = mean(caseDef.sus.kt(1:2));
                caseDef.tire.ktRear = mean(caseDef.sus.kt(3:4));
                report.warnings{end+1,1} = ...
                    'tire.fixed requested but tire.ktFront/ktRear missing; fallback to deprecated sus.kt average.';
            else
                report.messages{end+1,1} = 'tire.mode=fixed requires tire.ktFront and tire.ktRear.';
            end
        else
            caseDef.tire.ktFront = tireKtFront;
            caseDef.tire.ktRear = tireKtRear;
        end
    case 'range'
        [fRange, okFRng, msgFRng] = normalize_range_triplet(caseDef.tire.ktFrontRange, 'tire.ktFrontRange');
        [rRange, okRRng, msgRRng] = normalize_range_triplet(caseDef.tire.ktRearRange, 'tire.ktRearRange');
        if ~okFRng; report.messages{end+1,1} = msgFRng; else; caseDef.tire.ktFrontRange = fRange; end
        if ~okRRng; report.messages{end+1,1} = msgRRng; else; caseDef.tire.ktRearRange = rRange; end
end

% ===== tireOp 输入层检查 =====
[tireOpMsgs, caseDef] = local_validate_tire_op(caseDef);
report.messages = [report.messages; tireOpMsgs(:)];

% ===== rules 字段检查 =====
ruleFields = {'ruleSet','minStaticGroundClearance','minUsableWheelTravelTotal','minJounce', ...
    'staticGroundClearanceSource','staticGroundClearanceClause', ...
    'staticGroundClearanceEvidenceStatus','travelConstraintSource', ...
    'travelConstraintClause','travelEvidenceStatus','enforceRules'};
for i = 1:numel(ruleFields)
    if ~isfield(caseDef.rules, ruleFields{i})
        report.messages{end+1,1} = sprintf('caseDef.rules.%s missing.', ruleFields{i});
    end
end
if ~ischar(caseDef.rules.ruleSet) && ~isstring(caseDef.rules.ruleSet)
    report.messages{end+1,1} = 'caseDef.rules.ruleSet must be char/string.';
end
ruleTextFields = {'staticGroundClearanceSource','staticGroundClearanceClause', ...
    'staticGroundClearanceEvidenceStatus','travelConstraintSource', ...
    'travelConstraintClause','travelEvidenceStatus'};
for i = 1:numel(ruleTextFields)
    fn = ruleTextFields{i};
    if ~local_is_string_like(caseDef.rules.(fn))
        report.messages{end+1,1} = sprintf('caseDef.rules.%s must be char/string scalar.', fn);
    end
end
if ~is_finite_scalar(caseDef.rules.minStaticGroundClearance) || caseDef.rules.minStaticGroundClearance < 0
    report.messages{end+1,1} = 'caseDef.rules.minStaticGroundClearance must be >=0 scalar.';
end
if ~is_finite_scalar(caseDef.rules.minUsableWheelTravelTotal) || caseDef.rules.minUsableWheelTravelTotal < 0
    report.messages{end+1,1} = 'caseDef.rules.minUsableWheelTravelTotal must be >=0 scalar.';
end
if ~is_finite_scalar(caseDef.rules.minJounce) || caseDef.rules.minJounce < 0
    report.messages{end+1,1} = 'caseDef.rules.minJounce must be >=0 scalar.';
end
if ~is_logical_scalar(caseDef.rules.enforceRules)
    report.messages{end+1,1} = 'caseDef.rules.enforceRules must be logical scalar.';
end
caseDef.rules.enforceRules = logical(caseDef.rules.enforceRules);

% ===== targets 字段检查 =====
targetFields = {'minDynamicClearance','maxPitchDeg','maxRollDeg','maxAeroLossPct','maxFrontShareMigrationPct','enforceTargets'};
for i = 1:numel(targetFields)
    if ~isfield(caseDef.targets, targetFields{i})
        report.messages{end+1,1} = sprintf('caseDef.targets.%s missing.', targetFields{i});
    end
end

if ~is_finite_scalar(caseDef.targets.minDynamicClearance)
    report.messages{end+1,1} = 'caseDef.targets.minDynamicClearance must be finite scalar.';
end
if is_finite_scalar(caseDef.targets.minDynamicClearance) && ...
        caseDef.targets.minDynamicClearance < 0
    report.messages{end+1,1} = 'caseDef.targets.minDynamicClearance must be >=0.';
end

optTargetFields = {'maxPitchDeg','maxRollDeg','maxAeroLossPct','maxFrontShareMigrationPct'};
for i = 1:numel(optTargetFields)
    fn = optTargetFields{i};
    if ~isempty(caseDef.targets.(fn))
        if ~is_finite_scalar(caseDef.targets.(fn))
            report.messages{end+1,1} = sprintf('caseDef.targets.%s must be finite scalar or empty.', fn);
        elseif caseDef.targets.(fn) < 0
            report.messages{end+1,1} = sprintf('caseDef.targets.%s must be >=0 when provided.', fn);
        end
    end
end
if ~is_logical_scalar(caseDef.targets.enforceTargets)
    report.messages{end+1,1} = 'caseDef.targets.enforceTargets must be logical scalar.';
end
caseDef.targets.enforceTargets = logical(caseDef.targets.enforceTargets);

% ===== bumpAdjust 字段检查 =====
bumpFields = {'enable','reserveFront','reserveRear','notes'};
for i = 1:numel(bumpFields)
    if ~isfield(caseDef.bumpAdjust, bumpFields{i})
        report.messages{end+1,1} = sprintf('caseDef.bumpAdjust.%s missing.', bumpFields{i});
    end
end
if ~is_logical_scalar(caseDef.bumpAdjust.enable)
    report.messages{end+1,1} = 'caseDef.bumpAdjust.enable must be logical scalar.';
else
    caseDef.bumpAdjust.enable = logical(caseDef.bumpAdjust.enable);
end

[reserveFront, okFrontReserve, msgFrontReserve] = ...
    normalize_nonnegative_scalar(caseDef.bumpAdjust.reserveFront, 'caseDef.bumpAdjust.reserveFront', true);
[reserveRear, okRearReserve, msgRearReserve] = ...
    normalize_nonnegative_scalar(caseDef.bumpAdjust.reserveRear, 'caseDef.bumpAdjust.reserveRear', true);
if ~okFrontReserve
    report.messages{end+1,1} = msgFrontReserve;
end
if ~okRearReserve
    report.messages{end+1,1} = msgRearReserve;
end
if okFrontReserve && okRearReserve
    filledStr = string(filled);
    frontWasFilled = any(contains(filledStr, "bumpAdjust.reserveFront"));
    rearWasFilled = any(contains(filledStr, "bumpAdjust.reserveRear"));
    if rearWasFilled && ~frontWasFilled
        reserveRear = reserveFront;
    elseif frontWasFilled && ~rearWasFilled
        reserveFront = reserveRear;
    elseif isempty(reserveFront) && isempty(reserveRear)
        reserveFront = 0.0;
        reserveRear = 0.0;
    elseif isempty(reserveFront)
        reserveFront = reserveRear;
    elseif isempty(reserveRear)
        reserveRear = reserveFront;
    end
    caseDef.bumpAdjust.reserveFront = reserveFront;
    caseDef.bumpAdjust.reserveRear = reserveRear;
end
if ~ischar(caseDef.bumpAdjust.notes) && ~isstring(caseDef.bumpAdjust.notes)
    report.messages{end+1,1} = 'caseDef.bumpAdjust.notes must be char/string.';
end

% ===== mapType 检查 =====
[mapTypeOk, mapTypeText] = local_validate_enum_string( ...
    caseDef.aero.mapType, {'function_handle','table_lookup'});
mapType = string(mapTypeText);
if ~mapTypeOk
    report.messages{end+1, 1} = 'caseDef.aero.mapType must be ''function_handle'' or ''table_lookup''.';
end

if mapType == "table_lookup"
    mapReq = {'hfGrid','hrGrid','phiGrid','betaGrid','CzTable','CdTable','frontShareTable'};
    for i = 1:numel(mapReq)
        if ~isfield(caseDef.aero.mapData, mapReq{i})
            report.messages{end+1, 1} = sprintf('caseDef.aero.mapData.%s missing.', mapReq{i});
        end
    end

    if all(isfield(caseDef.aero.mapData, mapReq))
        gridFields = {'hfGrid','hrGrid','phiGrid','betaGrid'};
        for i = 1:numel(gridFields)
            fn = gridFields{i};
            grid = caseDef.aero.mapData.(fn);
            if ~(isnumeric(grid) && isreal(grid) && isvector(grid) && ...
                    numel(grid) >= 2 && all(isfinite(grid(:))) && all(diff(grid(:)) > 0))
                report.messages{end+1, 1} = sprintf( ...
                    'caseDef.aero.mapData.%s must be a finite, strictly increasing numeric vector with at least two points.', fn);
            end
        end

        n1 = numel(caseDef.aero.mapData.hfGrid);
        n2 = numel(caseDef.aero.mapData.hrGrid);
        n3 = numel(caseDef.aero.mapData.phiGrid);
        n4 = numel(caseDef.aero.mapData.betaGrid);
        szExpect = [n1, n2, n3, n4];

        if ~isequal(size(caseDef.aero.mapData.CzTable), szExpect)
            report.messages{end+1, 1} = 'CzTable size must match [numel(hfGrid), numel(hrGrid), numel(phiGrid), numel(betaGrid)].';
        end
        if ~isequal(size(caseDef.aero.mapData.CdTable), szExpect)
            report.messages{end+1, 1} = 'CdTable size must match [numel(hfGrid), numel(hrGrid), numel(phiGrid), numel(betaGrid)].';
        end
        if ~isequal(size(caseDef.aero.mapData.frontShareTable), szExpect)
            report.messages{end+1, 1} = 'frontShareTable size must match [numel(hfGrid), numel(hrGrid), numel(phiGrid), numel(betaGrid)].';
        end
        tableFields = {'CzTable','CdTable','frontShareTable'};
        for i = 1:numel(tableFields)
            fn = tableFields{i};
            values = caseDef.aero.mapData.(fn);
            if ~(isnumeric(values) && isreal(values) && ...
                    all(~isinf(values(:))) && any(isfinite(values(:))))
                report.messages{end+1, 1} = sprintf( ...
                    ['caseDef.aero.mapData.%s must be real numeric, contain at least one ', ...
                    'finite value, and contain no Inf. NaN gaps are handled by interpolation fallback.'], fn);
            end
        end
        frontShareValues = caseDef.aero.mapData.frontShareTable;
        if isnumeric(frontShareValues)
            finiteFrontShare = frontShareValues(isfinite(frontShareValues));
            if any(finiteFrontShare(:) < 0 | finiteFrontShare(:) > 1)
                report.messages{end+1, 1} = 'frontShareTable values must remain within [0, 1].';
            end
        end
        dragValues = caseDef.aero.mapData.CdTable;
        if isnumeric(dragValues)
            finiteDrag = dragValues(isfinite(dragValues));
            if any(finiteDrag(:) < 0)
                report.messages{end+1, 1} = 'CdTable values must be nonnegative.';
            end
        end
    end
end

if ~is_finite_scalar(caseDef.aero.rho) || caseDef.aero.rho <= 0
    report.messages{end+1, 1} = 'caseDef.aero.rho must be a finite positive scalar.';
end
if ~is_finite_scalar(caseDef.aero.Aref) || caseDef.aero.Aref <= 0
    report.messages{end+1, 1} = 'caseDef.aero.Aref must be a finite positive scalar.';
end
if ~is_finite_scalar(caseDef.aero.hDrag)
    report.messages{end+1, 1} = 'caseDef.aero.hDrag must be a finite scalar signed relative to the CG.';
end

% ===== longitudinal direct-path parameters =====
antiFields = {'antiDiveF','antiLiftR','antiSquatR'};
for i = 1:numel(antiFields)
    fn = antiFields{i};
    value = caseDef.longi.(fn);
    if ~is_finite_scalar(value) || value < 0 || value > 1
        report.messages{end+1, 1} = sprintf( ...
            'caseDef.longi.%s must be a finite fraction in [0,1].', fn);
    end
end
biasFields = {'brakeBiasF','driveBiasR'};
for i = 1:numel(biasFields)
    fn = biasFields{i};
    value = caseDef.longi.(fn);
    if ~is_finite_scalar(value) || value < 0 || value > 1
        report.messages{end+1, 1} = sprintf( ...
            'caseDef.longi.%s must be a finite fraction in [0,1].', fn);
    end
end
if is_finite_scalar(caseDef.longi.driveBiasR) && caseDef.longi.driveBiasR < 1
    report.warnings{end+1, 1} = [ ...
        'caseDef.longi.driveBiasR < 1: the current acceleration anti model ', ...
        'assumes the front driven share has zero direct anti-lift contribution.'];
end

% ===== aero provenance contract =====
aeroTextFields = {'evidenceStatus','mapSource','nominalSource','mapLoadStatus', ...
    'mapLoadMessage','nominalLoadStatus','nominalLoadMessage'};
for i = 1:numel(aeroTextFields)
    fn = aeroTextFields{i};
    if ~local_is_string_like(caseDef.aero.(fn))
        report.messages{end+1, 1} = sprintf( ...
            'caseDef.aero.%s must be a char/string scalar.', fn);
    end
end
if local_is_string_like(caseDef.aero.evidenceStatus)
    evidenceStatus = lower(strtrim(char(string(caseDef.aero.evidenceStatus))));
    if ~ismember(evidenceStatus, {'unverified','synthetic_demo','validated'})
        report.messages{end+1, 1} = ...
            'caseDef.aero.evidenceStatus must be unverified, synthetic_demo, or validated.';
    else
        caseDef.aero.evidenceStatus = evidenceStatus;
        if strcmp(evidenceStatus, 'validated')
            mapSourceEmpty = ~local_is_string_like(caseDef.aero.mapSource) || ...
                isempty(strtrim(char(string(caseDef.aero.mapSource))));
            nominalSourceEmpty = ~local_is_string_like(caseDef.aero.nominalSource) || ...
                isempty(strtrim(char(string(caseDef.aero.nominalSource))));
            if mapSourceEmpty || nominalSourceEmpty
                report.messages{end+1, 1} = ...
                    'Validated aero evidence requires nonempty mapSource and nominalSource.';
            end
        end
    end
end
loadStatusAllowed = {'loaded','provided_inline','not_applicable', ...
    'fallback_missing','fallback_invalid','fallback_error'};
loadStatusFields = {'mapLoadStatus','nominalLoadStatus'};
for i = 1:numel(loadStatusFields)
    fn = loadStatusFields{i};
    if local_is_string_like(caseDef.aero.(fn))
        value = lower(strtrim(char(string(caseDef.aero.(fn)))));
        if ~ismember(value, loadStatusAllowed)
            report.messages{end+1, 1} = sprintf( ...
                'caseDef.aero.%s has an unsupported status.', fn);
        else
            caseDef.aero.(fn) = value;
        end
    end
end

% A missing nominal reference is allowed so downstream validity can report
% "Not Evaluated". A provided table, however, must be internally coherent.
if isstruct(caseDef.aero.nominalRef) && ~isscalar(caseDef.aero.nominalRef)
    report.messages{end+1, 1} = ...
        'caseDef.aero.nominalRef must be a scalar struct.';
elseif isstruct(caseDef.aero.nominalRef) && ~isempty(fieldnames(caseDef.aero.nominalRef))
    nominalMsgs = local_validate_nominal_reference(caseDef.aero.nominalRef);
    report.messages = [report.messages; nominalMsgs(:)];
elseif ~(isstruct(caseDef.aero.nominalRef) || isa(caseDef.aero.nominalRef, 'function_handle'))
    report.messages{end+1, 1} = ...
        'caseDef.aero.nominalRef must be a struct or function handle.';
end

% ===== reference geometry / clearance contract =====
refScalarFields = {'xAeroF','xAeroR','hAeroF0','hAeroR0'};
for i = 1:numel(refScalarFields)
    fn = refScalarFields{i};
    if ~is_finite_scalar(caseDef.ref.(fn))
        report.messages{end+1, 1} = sprintf( ...
            'caseDef.ref.%s must be a finite numeric scalar.', fn);
    end
end
clearanceNumericOk = isnumeric(caseDef.ref.xClear) && isreal(caseDef.ref.xClear) && ...
    isnumeric(caseDef.ref.yClear) && isreal(caseDef.ref.yClear) && ...
    isnumeric(caseDef.ref.hClear0) && isreal(caseDef.ref.hClear0) && ...
    all(isfinite(caseDef.ref.xClear(:))) && all(isfinite(caseDef.ref.yClear(:))) && ...
    all(isfinite(caseDef.ref.hClear0(:)));
if clearanceNumericOk
    xc = caseDef.ref.xClear(:);
    yc = caseDef.ref.yClear(:);
    hc = caseDef.ref.hClear0(:);
else
    xc = [];
    yc = [];
    hc = [];
    report.messages{end+1, 1} = ...
        'caseDef.ref.xClear/yClear/hClear0 must be finite real numeric arrays.';
end
nameClearOk = (iscell(caseDef.ref.nameClear) && ...
    all(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), caseDef.ref.nameClear(:)))) || ...
    (isstring(caseDef.ref.nameClear) && isvector(caseDef.ref.nameClear));
if nameClearOk
    caseDef.ref.nameClear = cellstr(string(caseDef.ref.nameClear(:)));
else
    report.messages{end+1, 1} = ...
        'caseDef.ref.nameClear must be a cell/string vector of point names.';
end
nc = numel(caseDef.ref.nameClear);
if ~clearanceNumericOk || ...
        ~nameClearOk || ...
        ~(numel(xc) == numel(yc) && numel(yc) == numel(hc) && numel(hc) == nc)
    report.messages{end+1, 1} = 'caseDef.ref.xClear/yClear/hClear0/nameClear size mismatch.';
else
    caseDef.ref.xClear = xc;
    caseDef.ref.yClear = yc;
    caseDef.ref.hClear0 = hc;
    caseDef.ref.nameClear = caseDef.ref.nameClear(:);
end

% ===== 工况字段检查 =====
manFields = {'V','ax','ay','beta'};
for i = 1:numel(manFields)
    fn = manFields{i};
    if ~is_finite_scalar(caseDef.man.(fn))
        report.messages{end+1, 1} = sprintf('caseDef.man.%s must be finite numeric scalar.', fn);
    end
end
if is_finite_scalar(caseDef.man.V) && caseDef.man.V < 0
    report.messages{end+1, 1} = 'caseDef.man.V must be >= 0.';
end

% ===== 求解器字段检查 =====
solverFields = {'tol','maxIter','relax','useAeroIter','verbose', ...
    'exportDebug','initialGuess','checkWheelTravel','checkShockStroke', ...
    'strictTravelViolation','errorOnInterpFailure','rangeUseNominalAsPrimary', ...
    'useNonlinearCorner','warnOnDeprecatedInput'};
for i = 1:numel(solverFields)
    fn = solverFields{i};
    if ~isfield(caseDef.solver, fn)
        report.messages{end+1, 1} = sprintf('caseDef.solver.%s missing.', fn);
    end
end

if isnumeric(caseDef.solver.initialGuess) && isreal(caseDef.solver.initialGuess)
    caseDef.solver.initialGuess = caseDef.solver.initialGuess(:);
else
    caseDef.solver.initialGuess = nan(0,1);
end
if numel(caseDef.solver.initialGuess) ~= 3 || any(~isfinite(caseDef.solver.initialGuess))
    report.messages{end+1, 1} = ...
        'caseDef.solver.initialGuess must be a finite real numeric [3x1].';
end
if ~is_finite_scalar(caseDef.solver.maxIter) || caseDef.solver.maxIter < 1 ...
        || caseDef.solver.maxIter ~= floor(caseDef.solver.maxIter)
    report.messages{end+1, 1} = 'caseDef.solver.maxIter must be a positive integer.';
end
if ~is_finite_scalar(caseDef.solver.tol) || caseDef.solver.tol <= 0
    report.messages{end+1, 1} = 'caseDef.solver.tol must be a finite positive scalar.';
end
if ~is_finite_scalar(caseDef.solver.relax) || caseDef.solver.relax <= 0 || caseDef.solver.relax > 1
    report.messages{end+1, 1} = 'caseDef.solver.relax must be in (0,1].';
end
boolFields = {'useAeroIter','verbose','exportDebug','checkWheelTravel','checkShockStroke', ...
    'strictTravelViolation','errorOnInterpFailure','rangeUseNominalAsPrimary', ...
    'useNonlinearCorner','warnOnDeprecatedInput'};
for i = 1:numel(boolFields)
    fn = boolFields{i};
    if ~is_logical_scalar(caseDef.solver.(fn))
        report.messages{end+1, 1} = sprintf('caseDef.solver.%s must be logical scalar.', fn);
    else
        caseDef.solver.(fn) = logical(caseDef.solver.(fn));
    end
end

if caseDef.solver.useNonlinearCorner
    report.warnings{end+1, 1} = 'caseDef.solver.useNonlinearCorner is deprecated and ignored in V1.5.';
end

report.badInput = ~isempty(report.messages);
end

function defaults = local_default_case()
defaults = struct();

defaults.meta = struct( ...
    'name', 'unnamed_case', ...
    'version', 'V1.5', ...
    'description', '', ...
    'author', '', ...
    'date', char(datetime('today', 'Format', 'yyyy-MM-dd')), ...
    'notes', '');

defaults.veh = struct( ...
    'm', 260.0, ...
    'g', 9.81, ...
    'L', 1.58, ...
    'wf_static', 0.5, ...
    'lf', [], ...
    'lr', [], ...
    'tf', 1.2, ...
    'tr', 1.2, ...
    'hCG', 0.27, ...
    'hRCf', 0.03, ...
    'hRCr', 0.05);

defaults.sus = struct( ...
    'ks', 40000 .* ones(4,1), ...
    'mr', 0.9 .* ones(4,1), ...
    'kw', [], ...
    'kt', [], ...
    'jounceMax', 0.05 .* ones(4,1), ...
    'droopMax', 0.03 .* ones(4,1), ...
    'kArbF', 0.0, ...
    'kArbR', 0.0, ...
    'shockLenExtended', [], ...
    'shockLenCompressed', [], ...
    'shockLenStatic', [], ...
    ... % deprecated 兼容字段
    'kBump', [], ...
    'bumpGap', [], ...
    'kDroop', [], ...
    'droopGap', []);

defaults.tire = struct( ...
    'mode', 'off', ...
    'ktFront', [], ...
    'ktRear', [], ...
    'ktFrontRange', [], ...
    'ktRearRange', [], ...
    'notes', '', ...
    'forceModel', struct( ...
        'enable', false, ...
        'sourceType', 'table_struct', ...
        'file', '', ...
        'data', struct(), ...
        'mode', 'pure_plus_combined_proxy', ...
        'outOfRangePolicy', 'warn_clamp', ...
        'includeAligningMoment', true, ...
        'alphaUnit', 'deg', ...
        'gammaUnit', 'deg', ...
        'kappaUnit', 'ratio', ...
        'FzUnit', 'N', ...
        'forceUnit', 'N', ...
        'momentUnit', 'N*m', ...
        'pressureUnit', 'Pa', ...
        'combinedProxy', struct( ...
            'enable', true, ...
            'type', 'friction_ellipse', ...
            'exponent', 2.0, ...
            'useSeparateBrakeTraction', true)));

defaults.tireOp = struct( ...
    'mode', 'proxy', ...
    'alpha', 0.0, ...
    'kappa', 0.0, ...
    'gamma', 0.0, ...
    'pressure', [], ...
    'alphaUnit', 'rad', ...
    'gammaUnit', 'rad', ...
    'kappaUnit', 'ratio', ...
    'pressureUnit', 'Pa', ...
    'alphaFront', 0.0, ...
    'alphaRear', 0.0, ...
    'kappaFront', 0.0, ...
    'kappaRear', 0.0, ...
    'gammaStatic', 0.0, ...
    'camberGainSusp', 0.0, ...
    'camberGainRoll', 0.0, ...
    'toeStatic', 0.0, ...
    'scan', struct( ...
        'enable', false, ...
        'field', '', ...
        'values', [], ...
        'unit', '', ...
        'applyMode', 'all_corners', ...
        'notes', ''));

defaults.rules = struct( ...
    'ruleSet', 'unverified_project_constraints', ...
    'minStaticGroundClearance', 0.030, ...
    'minUsableWheelTravelTotal', 0.050, ...
    'minJounce', 0.025, ...
    'staticGroundClearanceSource', '', ...
    'staticGroundClearanceClause', '', ...
    'staticGroundClearanceEvidenceStatus', 'unverified', ...
    'travelConstraintSource', '', ...
    'travelConstraintClause', '', ...
    'travelEvidenceStatus', 'unverified', ...
    'enforceRules', true);

defaults.targets = struct( ...
    'minDynamicClearance', 0.005, ...
    'maxPitchDeg', [], ...
    'maxRollDeg', [], ...
    'maxAeroLossPct', [], ...
    'maxFrontShareMigrationPct', [], ...
    'enforceTargets', true);

defaults.bumpAdjust = struct( ...
    'enable', false, ...
    'reserveFront', 0.0, ...
    'reserveRear', 0.0, ...
    'notes', '');

defaults.longi = struct( ...
    'antiDiveF', 0.0, ...
    'antiLiftR', 0.0, ...
    'antiSquatR', 0.0, ...
    'brakeBiasF', 0.6, ...
    'driveBiasR', 1.0);

defaults.aero = struct( ...
    'rho', 1.225, ...
    'Aref', 1.2, ...
    'mapType', 'function_handle', ...
    'mapData', struct(), ...
    'nominalRef', struct(), ...
    'evidenceStatus', 'unverified', ...
    'mapSource', '', ...
    'nominalSource', '', ...
    'mapLoadStatus', 'not_applicable', ...
    'mapLoadMessage', '', ...
    'nominalLoadStatus', 'not_applicable', ...
    'nominalLoadMessage', '', ...
    'hDrag', 0.1);

defaults.ref = struct( ...
    'xAeroF', 0.45, ...
    'xAeroR', -0.50, ...
    'hAeroF0', 0.03, ...
    'hAeroR0', 0.04, ...
    'xClear', [0.0; 0.5], ...
    'yClear', [0.0; 0.0], ...
    'hClear0', [0.03; 0.03], ...
    'nameClear', {'mid'; 'front'});

defaults.man = struct( ...
    'V', 0.0, ...
    'ax', 0.0, ...
    'ay', 0.0, ...
    'beta', 0.0, ...
    'mode', 'static', ...
    'description', '', ...
    'tag', '');

defaults.solver = default_solver_options();
end

function [vec, ok, msg] = normalize_corner_vector(x, fieldName)
ok = true;
msg = '';

if ~isnumeric(x) || isempty(x)
    ok = false;
    vec = [];
    msg = sprintf('caseDef.sus.%s must be numeric [4x1].', fieldName);
    return;
end

if isscalar(x)
    vec = repmat(double(x), 4, 1);
elseif numel(x) == 4
    vec = double(x(:));
else
    ok = false;
    vec = [];
    msg = sprintf('caseDef.sus.%s must be scalar or have 4 elements.', fieldName);
    return;
end

if any(~isfinite(vec))
    ok = false;
    msg = sprintf('caseDef.sus.%s contains non-finite values.', fieldName);
end
if any(vec <= 0)
    ok = false;
    msg = sprintf('caseDef.sus.%s must be > 0.', fieldName);
end
end

function [val, ok, msg] = validate_scalar_or_corner(x, fieldName)
ok = true;
msg = '';

if ~isnumeric(x) || isempty(x)
    ok = false;
    val = [];
    msg = sprintf('caseDef.sus.%s must be numeric scalar or 4-element array.', fieldName);
    return;
end

if isscalar(x)
    val = double(x);
elseif numel(x) == 4
    val = double(x(:));
else
    ok = false;
    val = [];
    msg = sprintf('caseDef.sus.%s must be scalar or have 4 elements.', fieldName);
    return;
end

if any(~isfinite(val))
    ok = false;
    msg = sprintf('caseDef.sus.%s contains non-finite values.', fieldName);
end
end

function vec4 = expand_scalar_or_corner(x)
if isscalar(x)
    vec4 = repmat(double(x), 4, 1);
else
    vec4 = double(x(:));
end
end

function [vec4, ok, msg] = normalize_axle_or_corner(x, fieldName, allowEmpty)
ok = true;
msg = '';
vec4 = [];

if nargin < 3
    allowEmpty = false;
end
if isempty(x)
    if allowEmpty
        return;
    end
    ok = false;
    msg = sprintf('%s cannot be empty.', fieldName);
    return;
end
if ~isnumeric(x)
    ok = false;
    msg = sprintf('%s must be numeric.', fieldName);
    return;
end

x = double(x(:));
if isscalar(x)
    vec4 = repmat(x, 4, 1);
elseif numel(x) == 2
    vec4 = [x(1); x(1); x(2); x(2)];
elseif numel(x) == 4
    vec4 = x;
else
    ok = false;
    msg = sprintf('%s must be scalar, [front rear], or [4x1].', fieldName);
    return;
end

if any(~isfinite(vec4)) || any(vec4 <= 0)
    ok = false;
    msg = sprintf('%s must contain finite positive values.', fieldName);
end
end

function [triplet, ok, msg] = normalize_range_triplet(x, fieldName)
ok = true;
msg = '';
triplet = [];

if isempty(x) || ~isnumeric(x)
    ok = false;
    msg = sprintf('%s must be numeric with 2 or 3 elements.', fieldName);
    return;
end

x = double(x(:));
if numel(x) == 2
    lo = min(x);
    hi = max(x);
    triplet = [lo; 0.5 * (lo + hi); hi];
elseif numel(x) == 3
    triplet = sort(x, 'ascend');
else
    ok = false;
    msg = sprintf('%s must have 2 or 3 elements.', fieldName);
    return;
end

if any(~isfinite(triplet)) || any(triplet <= 0)
    ok = false;
    msg = sprintf('%s must contain finite positive values.', fieldName);
    return;
end
end

function tf = is_finite_scalar(x)
tf = isnumeric(x) && isscalar(x) && isfinite(x);
end

function tf = is_logical_scalar(x)
tf = (islogical(x) && isscalar(x)) || (isnumeric(x) && isscalar(x) && ismember(x, [0, 1]));
end

function [val, ok, msg] = normalize_nonnegative_scalar(x, fieldName, allowEmpty)
ok = true;
msg = '';
val = [];
if nargin < 3
    allowEmpty = false;
end
if isempty(x)
    if allowEmpty
        return;
    end
    ok = false;
    msg = sprintf('%s cannot be empty.', fieldName);
    return;
end
if ~(isnumeric(x) && isscalar(x) && isfinite(x))
    ok = false;
    msg = sprintf('%s must be a finite numeric scalar.', fieldName);
    return;
end
val = double(x);
if val < 0
    ok = false;
    msg = sprintf('%s must be >= 0.', fieldName);
end
end

function [messages, warningsOut, caseDef] = local_validate_tire_force_model(caseDef)
%LOCAL_VALIDATE_TIRE_FORCE_MODEL 校验 V1.5 tire.forceModel 输入层。
messages = {};
warningsOut = {};

defaults = local_default_case();
if ~isstruct(caseDef.tire.forceModel)
    caseDef.tire.forceModel = defaults.tire.forceModel;
    messages{end+1,1} = 'caseDef.tire.forceModel must be a struct.';
    return;
end
if ~isstruct(caseDef.tire.forceModel.combinedProxy)
    caseDef.tire.forceModel.combinedProxy = defaults.tire.forceModel.combinedProxy;
    messages{end+1,1} = 'caseDef.tire.forceModel.combinedProxy must be a struct.';
    return;
end

if ~is_logical_scalar(caseDef.tire.forceModel.enable)
    messages{end+1,1} = 'caseDef.tire.forceModel.enable must be logical scalar.';
else
    caseDef.tire.forceModel.enable = logical(caseDef.tire.forceModel.enable);
end
if ~is_logical_scalar(caseDef.tire.forceModel.includeAligningMoment)
    messages{end+1,1} = 'caseDef.tire.forceModel.includeAligningMoment must be logical scalar.';
else
    caseDef.tire.forceModel.includeAligningMoment = logical(caseDef.tire.forceModel.includeAligningMoment);
end
if ~is_logical_scalar(caseDef.tire.forceModel.combinedProxy.enable)
    messages{end+1,1} = 'caseDef.tire.forceModel.combinedProxy.enable must be logical scalar.';
else
    caseDef.tire.forceModel.combinedProxy.enable = logical(caseDef.tire.forceModel.combinedProxy.enable);
end
if ~is_logical_scalar(caseDef.tire.forceModel.combinedProxy.useSeparateBrakeTraction)
    messages{end+1,1} = 'caseDef.tire.forceModel.combinedProxy.useSeparateBrakeTraction must be logical scalar.';
else
    caseDef.tire.forceModel.combinedProxy.useSeparateBrakeTraction = ...
        logical(caseDef.tire.forceModel.combinedProxy.useSeparateBrakeTraction);
end

if ~(isnumeric(caseDef.tire.forceModel.combinedProxy.exponent) && isscalar(caseDef.tire.forceModel.combinedProxy.exponent) ...
        && isfinite(caseDef.tire.forceModel.combinedProxy.exponent) && caseDef.tire.forceModel.combinedProxy.exponent >= 1)
    messages{end+1,1} = ...
        'caseDef.tire.forceModel.combinedProxy.exponent must be a finite scalar >= 1.';
end

[okSrc, srcVal] = local_validate_enum_string(caseDef.tire.forceModel.sourceType, ...
    {'table_struct','excel_file','csv_longform','tir_file','function_handle'});
if ~okSrc
    messages{end+1,1} = ['caseDef.tire.forceModel.sourceType must be one of ', ...
        '''table_struct'', ''excel_file'', ''csv_longform'', ''tir_file'', ''function_handle''.'];
else
    caseDef.tire.forceModel.sourceType = srcVal;
end

[okMode, modeVal] = local_validate_enum_string(caseDef.tire.forceModel.mode, ...
    {'pure_tables','pure_plus_combined_proxy'});
if ~okMode
    messages{end+1,1} = ...
        'caseDef.tire.forceModel.mode must be ''pure_tables'' or ''pure_plus_combined_proxy''.';
else
    caseDef.tire.forceModel.mode = modeVal;
end

[okPolicy, policyVal] = local_validate_enum_string(caseDef.tire.forceModel.outOfRangePolicy, ...
    {'warn_clamp','error','nan'});
if ~okPolicy
    messages{end+1,1} = ...
        'caseDef.tire.forceModel.outOfRangePolicy must be ''warn_clamp'', ''error'', or ''nan''.';
else
    caseDef.tire.forceModel.outOfRangePolicy = policyVal;
end

[okType, typeVal] = local_validate_enum_string(caseDef.tire.forceModel.combinedProxy.type, ...
    {'friction_ellipse'});
if ~okType
    messages{end+1,1} = ...
        'caseDef.tire.forceModel.combinedProxy.type must be ''friction_ellipse''; no other proxy type is implemented.';
else
    caseDef.tire.forceModel.combinedProxy.type = typeVal;
end

unitMsgs = { ...
    local_validate_unit_field(caseDef.tire.forceModel.alphaUnit, {'deg','rad'}, 'caseDef.tire.forceModel.alphaUnit'); ...
    local_validate_unit_field(caseDef.tire.forceModel.gammaUnit, {'deg','rad'}, 'caseDef.tire.forceModel.gammaUnit'); ...
    local_validate_unit_field(caseDef.tire.forceModel.kappaUnit, {'ratio','pct','percent','unitless'}, 'caseDef.tire.forceModel.kappaUnit'); ...
    local_validate_unit_field(caseDef.tire.forceModel.FzUnit, {'n','kn'}, 'caseDef.tire.forceModel.FzUnit'); ...
    local_validate_unit_field(caseDef.tire.forceModel.forceUnit, {'n','kn'}, 'caseDef.tire.forceModel.forceUnit'); ...
    local_validate_unit_field(caseDef.tire.forceModel.momentUnit, {'n*m','nm','kn*m','knm'}, 'caseDef.tire.forceModel.momentUnit'); ...
    local_validate_unit_field(caseDef.tire.forceModel.pressureUnit, {'pa','kpa','bar','psi'}, 'caseDef.tire.forceModel.pressureUnit') ...
    };
messages = [messages; unitMsgs(~cellfun(@isempty, unitMsgs))];

if ~local_is_string_like(caseDef.tire.forceModel.file)
    messages{end+1,1} = 'caseDef.tire.forceModel.file must be char/string.';
end

if caseDef.tire.forceModel.enable
    src = lower(strtrim(char(string(caseDef.tire.forceModel.sourceType))));
    if strcmp(src, 'excel_file') && isempty(caseDef.tire.forceModel.file)
        warningsOut{end+1,1} = 'tire.forceModel.enable=true with sourceType=excel_file but file is empty; tire evaluator will fail until a file is provided.';
    end
    if strcmp(src, 'table_struct') && (~isstruct(caseDef.tire.forceModel.data) || isempty(fieldnames(caseDef.tire.forceModel.data)))
        warningsOut{end+1,1} = 'tire.forceModel.enable=true with sourceType=table_struct but data is empty; tire evaluator will fail until tables are provided.';
    end
    if ismember(src, {'csv_longform','tir_file','function_handle'})
        warningsOut{end+1,1} = ['Selected tire.forceModel.sourceType is reserved for future adapter work; ', ...
            'platform solve will continue, but tire evaluation may fail in V1.5 first release.'];
    end
end
end

function [messages, caseDef] = local_validate_tire_op(caseDef)
%LOCAL_VALIDATE_TIRE_OP 校验 V1.5 tireOp 输入层与 scan 定义。
messages = {};

defaults = local_default_case();
if ~isstruct(caseDef.tireOp)
    caseDef.tireOp = defaults.tireOp;
    messages{end+1,1} = 'caseDef.tireOp must be a struct.';
    return;
end
if ~isstruct(caseDef.tireOp.scan)
    caseDef.tireOp.scan = defaults.tireOp.scan;
    messages{end+1,1} = 'caseDef.tireOp.scan must be a struct.';
end

[okMode, modeVal] = local_validate_enum_string(caseDef.tireOp.mode, {'direct','proxy'});
if ~okMode
    messages{end+1,1} = 'caseDef.tireOp.mode must be ''direct'' or ''proxy''.';
else
    caseDef.tireOp.mode = modeVal;
end

unitMsgs = { ...
    local_validate_unit_field(caseDef.tireOp.alphaUnit, {'deg','rad'}, 'caseDef.tireOp.alphaUnit'); ...
    local_validate_unit_field(caseDef.tireOp.gammaUnit, {'deg','rad'}, 'caseDef.tireOp.gammaUnit'); ...
    local_validate_unit_field(caseDef.tireOp.kappaUnit, {'ratio','pct','percent','unitless'}, 'caseDef.tireOp.kappaUnit'); ...
    local_validate_unit_field(caseDef.tireOp.pressureUnit, {'pa','kpa','bar','psi'}, 'caseDef.tireOp.pressureUnit') ...
    };
messages = [messages; unitMsgs(~cellfun(@isempty, unitMsgs))];

if ~is_logical_scalar(caseDef.tireOp.scan.enable)
    messages{end+1,1} = 'caseDef.tireOp.scan.enable must be logical scalar.';
else
    caseDef.tireOp.scan.enable = logical(caseDef.tireOp.scan.enable);
end

if ~isempty(caseDef.tireOp.scan.field)
    [okField, fieldVal] = local_validate_enum_string(caseDef.tireOp.scan.field, {'alpha','kappa','gamma','pressure'});
    if ~okField
        messages{end+1,1} = 'caseDef.tireOp.scan.field must be ''alpha'', ''kappa'', ''gamma'', or ''pressure''.';
    else
        caseDef.tireOp.scan.field = fieldVal;
    end
end
if ~isempty(caseDef.tireOp.scan.applyMode)
    [okApply, applyVal] = local_validate_enum_string(caseDef.tireOp.scan.applyMode, {'all_corners','front_axle','rear_axle'});
    if ~okApply
        messages{end+1,1} = 'caseDef.tireOp.scan.applyMode must be ''all_corners'', ''front_axle'', or ''rear_axle''.';
    else
        caseDef.tireOp.scan.applyMode = applyVal;
    end
end
if ~isempty(caseDef.tireOp.scan.unit) && ~local_is_string_like(caseDef.tireOp.scan.unit)
    messages{end+1,1} = 'caseDef.tireOp.scan.unit must be char/string when provided.';
end
end

function [ok, valueOut] = local_validate_enum_string(valueIn, allowedSet)
%LOCAL_VALIDATE_ENUM_STRING 统一处理 char/string 枚举输入。
ok = false;
valueOut = '';
if ~local_is_string_like(valueIn)
    return;
end
valueOut = lower(strtrim(char(string(valueIn))));
ok = ismember(valueOut, allowedSet);
end

function messages = validate_struct_shape(actual, defaults, prefix)
%VALIDATE_STRUCT_SHAPE Reject non-struct values at schema struct nodes.
messages = {};
defaultFields = fieldnames(defaults);
for i = 1:numel(defaultFields)
    fn = defaultFields{i};
    defaultValue = defaults.(fn);
    if ~isstruct(defaultValue) || ~isfield(actual, fn) || isempty(actual.(fn))
        continue;
    end
    actualValue = actual.(fn);
    fieldPath = sprintf('%s.%s', prefix, fn);
    if strcmp(fieldPath, 'caseDef.aero.nominalRef') && isa(actualValue, 'function_handle')
        continue;
    end
    if ~isstruct(actualValue) || ~isscalar(actualValue)
        messages{end+1, 1} = sprintf('%s must be a scalar struct.', fieldPath); %#ok<AGROW>
        continue;
    end
    nestedMessages = validate_struct_shape(actualValue, defaultValue, fieldPath);
    messages = [messages; nestedMessages(:)]; %#ok<AGROW>
end
end

function msg = local_validate_unit_field(valueIn, allowedSet, fieldName)
%LOCAL_VALIDATE_UNIT_FIELD 生成统一的单位枚举报错信息。
msg = '';
[ok, ~] = local_validate_enum_string(valueIn, allowedSet);
if ~ok
    msg = sprintf('%s has unsupported unit string.', fieldName);
end
end

function messages = local_validate_nominal_reference(nominalRef)
%LOCAL_VALIDATE_NOMINAL_REFERENCE Validate a provided tabulated reference.
messages = {};
VGrid = [];
if isfield(nominalRef, 'VGrid'); VGrid = nominalRef.VGrid; end
if isempty(VGrid) && isfield(nominalRef, 'V'); VGrid = nominalRef.V; end
if isempty(VGrid)
    messages{end+1, 1} = ...
        'caseDef.aero.nominalRef requires VGrid (or V) when a table is provided.';
    return;
end
if ~(isnumeric(VGrid) && isreal(VGrid) && isvector(VGrid) && numel(VGrid) >= 2 && ...
        all(isfinite(VGrid(:))) && all(diff(VGrid(:)) > 0))
    messages{end+1, 1} = ...
        'caseDef.aero.nominalRef speed grid must be finite, strictly increasing, and have at least two points.';
    return;
end

FzGrid = [];
if isfield(nominalRef, 'FzNominal'); FzGrid = nominalRef.FzNominal; end
if isempty(FzGrid) && isfield(nominalRef, 'Fz'); FzGrid = nominalRef.Fz; end
if ~isempty(FzGrid) && ~(isnumeric(FzGrid) && isreal(FzGrid) && ...
        numel(FzGrid) == numel(VGrid) && all(isfinite(FzGrid(:))) && all(FzGrid(:) >= 0))
    messages{end+1, 1} = ...
        'caseDef.aero.nominalRef Fz values must be finite, nonnegative, and match the speed grid.';
end

frontShareGrid = [];
if isfield(nominalRef, 'frontShareNominal')
    frontShareGrid = nominalRef.frontShareNominal;
elseif isfield(nominalRef, 'frontShare')
    frontShareGrid = nominalRef.frontShare;
end
if ~isempty(frontShareGrid) && ~(isnumeric(frontShareGrid) && isreal(frontShareGrid) && ...
        numel(frontShareGrid) == numel(VGrid) && all(isfinite(frontShareGrid(:))) && ...
        all(frontShareGrid(:) >= 0 & frontShareGrid(:) <= 1))
    messages{end+1, 1} = ...
        'caseDef.aero.nominalRef front-share values must be finite, within [0,1], and match the speed grid.';
end
end

function tf = local_is_string_like(valueIn)
%LOCAL_IS_STRING_LIKE 判断值是否为 char 或 string 标量。
tf = ischar(valueIn) || (isstring(valueIn) && isscalar(valueIn));
end

function fieldsOut = filter_reportable_autofill_fields(fieldsIn)
%FILTER_REPORTABLE_AUTOFILL_FIELDS 过滤仅用于兼容层的 autofill 字段。
% 功能说明:
%   1) 保留 autofill 机制本身，避免破坏旧 case 兼容。
%   2) 对兼容层空默认字段不计入标准 case warning，减少噪声。
%   3) 当前标准 case 仍应显式给出活跃字段，不应依赖 autofill 成立。

if isempty(fieldsIn)
    fieldsOut = fieldsIn;
    return;
end

% 以下字段在标准 case 中允许保持“显式但非激活”状态：
% 1) table_struct 模式下 file 为空是合理的
% 2) scan.enable=false 时 field/values/unit 为空是合理的
compatOnly = [ ...
    "sus.kt"; ...
    "sus.kw"; ...
    "sus.kBump"; ...
    "sus.bumpGap"; ...
    "sus.kDroop"; ...
    "sus.droopGap"; ...
    "tire.forceModel.file"; ...
    "tireOp.scan.field"; ...
    "tireOp.scan.values"; ...
    "tireOp.scan.unit"; ...
    "aero.evidenceStatus"; ...
    "aero.mapSource"; ...
    "aero.nominalSource"; ...
    "aero.mapLoadStatus"; ...
    "aero.mapLoadMessage"; ...
    "aero.nominalLoadStatus"; ...
    "aero.nominalLoadMessage"; ...
    "rules.staticGroundClearanceSource"; ...
    "rules.staticGroundClearanceClause"; ...
    "rules.staticGroundClearanceEvidenceStatus"; ...
    "rules.travelConstraintSource"; ...
    "rules.travelConstraintClause"; ...
    "rules.travelEvidenceStatus" ...
    ];
fieldsStr = string(fieldsIn);
maskKeep = ~ismember(fieldsStr, compatOnly);
fieldsOut = fieldsIn(maskKeep);
end
