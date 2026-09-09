function tireOpNorm = normalize_tire_operating_points(caseDef, results, tireTableData)
%NORMALIZE_TIRE_OPERATING_POINTS 将 V1.5 direct/proxy 输入统一为四角点操作量。
% 功能说明:
%   1) 统一 direct / proxy 两种输入方式。
%   2) 自动把标量或轴级输入扩展成固定角点顺序 [FL FR RL RR]。
%   3) 将 alpha/kappa/gamma/pressure 转为内部 SI，并保留扫描配置。
%
% 输入:
%   caseDef       - 顶层输入结构，使用 caseDef.tireOp.*
%   results       - 平台收敛后的结果结构，用于读取 Fz、deltaSuspWheel、phi
%   tireTableData - 已归一化的轮胎表数据，用于提供 Meta 默认 pressure
%
% 输出:
%   tireOpNorm - 统一轮胎操作点结构，至少包含：
%                .alpha / .kappa / .gamma / .pressure / .Fz
%                .scan
%                .mode
%                .cornerNames
%
% 关键物理假设:
%   1) 轮胎操作点始终在平台主求解之后生成，不反向改写平台平衡方程。
%   2) proxy 模式中的 gamma 仅是概念设计近似，不等价于完整悬架运动学。
%   3) 角点顺序固定为 [FL FR RL RR]，便于 batch/demo/summary 统一处理。
%
% 单位约定:
%   alpha/gamma [rad]，kappa [-]，pressure [Pa]，Fz [N]

cornerNames = {'FL'; 'FR'; 'RL'; 'RR'};

if isfield(results.corners, 'FzWheel')
    Fz = results.corners.FzWheel(:);
elseif isfield(results.corners, 'FzTotal')
    Fz = results.corners.FzTotal(:);
else
    error('normalize_tire_operating_points:MissingFz', ...
        'Platform results must provide results.corners.FzWheel or results.corners.FzTotal.');
end

modeStr = lower(strtrim(char(string(caseDef.tireOp.mode))));
alphaUnit = local_normalize_unit_string(caseDef.tireOp.alphaUnit);
gammaUnit = local_normalize_unit_string(caseDef.tireOp.gammaUnit);
kappaUnit = local_normalize_unit_string(caseDef.tireOp.kappaUnit);
pressureUnit = local_normalize_unit_string(caseDef.tireOp.pressureUnit);
metaPressure = local_extract_meta_pressure(tireTableData);

switch modeStr
    case 'direct'
        alpha = local_convert_angle(local_expand_corner_value(caseDef.tireOp.alpha, 'tireOp.alpha'), alphaUnit);
        kappa = local_convert_kappa(local_expand_corner_value(caseDef.tireOp.kappa, 'tireOp.kappa'), kappaUnit);
        gamma = local_convert_angle(local_expand_corner_value(caseDef.tireOp.gamma, 'tireOp.gamma'), gammaUnit);
        pressure = local_expand_pressure(caseDef.tireOp.pressure, metaPressure, pressureUnit);

    case 'proxy'
        % proxy 模式下，先将轴级输入扩展成四角点，再叠加外倾与 toe 代理。
        alphaFront = local_convert_angle(local_expand_scalar(caseDef.tireOp.alphaFront, 'tireOp.alphaFront', 2), alphaUnit);
        alphaRear = local_convert_angle(local_expand_scalar(caseDef.tireOp.alphaRear, 'tireOp.alphaRear', 2), alphaUnit);
        kappaFront = local_convert_kappa(local_expand_scalar(caseDef.tireOp.kappaFront, 'tireOp.kappaFront', 2), kappaUnit);
        kappaRear = local_convert_kappa(local_expand_scalar(caseDef.tireOp.kappaRear, 'tireOp.kappaRear', 2), kappaUnit);

        gammaStatic = local_convert_angle(local_expand_corner_value(caseDef.tireOp.gammaStatic, 'tireOp.gammaStatic'), gammaUnit);
        camberGainSusp = local_expand_corner_value(caseDef.tireOp.camberGainSusp, 'tireOp.camberGainSusp');
        camberGainRoll = local_expand_corner_value(caseDef.tireOp.camberGainRoll, 'tireOp.camberGainRoll');
        toeStatic = local_convert_angle(local_expand_corner_value(caseDef.tireOp.toeStatic, 'tireOp.toeStatic'), alphaUnit);

        alpha = [alphaFront(:); alphaRear(:)] + toeStatic;
        kappa = [kappaFront(:); kappaRear(:)];

        % gamma 代理显式写为：
        % gamma = gammaStatic + camberGainSusp .* deltaSuspWheel + camberGainRoll .* phi
        % 这是概念设计阶段 operating point 近似，不等价于完整悬架运动学。
        deltaSuspWheel = results.corners.deltaSuspWheel(:);
        phi = results.state.phi;
        gamma = gammaStatic + camberGainSusp .* deltaSuspWheel + camberGainRoll .* phi;
        pressure = local_expand_pressure(caseDef.tireOp.pressure, metaPressure, pressureUnit);

    otherwise
        error('normalize_tire_operating_points:BadMode', 'Unsupported tireOp.mode: %s', modeStr);
end

local_validate_pressure_contract(pressure, metaPressure);

tireOpNorm = struct();
tireOpNorm.mode = modeStr;
tireOpNorm.cornerNames = cornerNames;
tireOpNorm.alpha = alpha(:);
tireOpNorm.kappa = kappa(:);
tireOpNorm.gamma = gamma(:);
tireOpNorm.pressure = pressure(:);
tireOpNorm.Fz = Fz(:);
tireOpNorm.alphaDeg = rad2deg(alpha(:));
tireOpNorm.gammaDeg = rad2deg(gamma(:));
tireOpNorm.sourcePressure = metaPressure;
tireOpNorm.scan = local_normalize_scan(caseDef.tireOp.scan, caseDef.tireOp, tireOpNorm);
end

function scan = local_normalize_scan(scanCfg, tireOpCfg, tireOpNorm)
%LOCAL_NORMALIZE_SCAN 统一扫描字段定义。
scan = struct( ...
    'enable', false, ...
    'field', '', ...
    'unit', '', ...
    'applyMode', 'all_corners', ...
    'valuesRaw', zeros(0,1), ...
    'valuesSI', zeros(0,1), ...
    'mask', true(4,1), ...
    'notes', '');

if ~isstruct(scanCfg) || ~isfield(scanCfg, 'enable') || ~logical(scanCfg.enable)
    return;
end
if ~isfield(scanCfg, 'field') || isempty(scanCfg.field) || ~isfield(scanCfg, 'values') || isempty(scanCfg.values)
    return;
end

fieldName = lower(strtrim(char(string(scanCfg.field))));
applyMode = lower(strtrim(char(string(scanCfg.applyMode))));
if isempty(applyMode)
    applyMode = 'all_corners';
end
mask = local_scan_mask(applyMode);

unitName = char(string(scanCfg.unit));
if isempty(unitName)
    switch fieldName
        case 'alpha'
            unitName = tireOpCfg.alphaUnit;
        case 'gamma'
            unitName = tireOpCfg.gammaUnit;
        case 'kappa'
            unitName = tireOpCfg.kappaUnit;
        case 'pressure'
            unitName = tireOpCfg.pressureUnit;
        otherwise
            unitName = '';
    end
end

valuesRaw = double(scanCfg.values(:));
switch fieldName
    case {'alpha', 'gamma'}
        valuesSI = local_convert_angle(valuesRaw, unitName);
    case 'kappa'
        valuesSI = local_convert_kappa(valuesRaw, unitName);
    case 'pressure'
        error('normalize_tire_operating_points:UnsupportedPressureScan', ...
            ['pressure scans are unsupported because the current tire-table schema ', ...
            'has no pressure interpolation dimension.']);
    otherwise
        error('normalize_tire_operating_points:BadScanField', ...
            'Unsupported tireOp.scan.field: %s', fieldName);
end

scan.enable = true;
scan.field = fieldName;
scan.unit = local_normalize_unit_string(unitName);
scan.applyMode = applyMode;
scan.valuesRaw = valuesRaw;
scan.valuesSI = valuesSI;
scan.mask = mask;
scan.base = tireOpNorm;
if isfield(scanCfg, 'notes')
    scan.notes = char(string(scanCfg.notes));
end
end

function mask = local_scan_mask(applyMode)
%LOCAL_SCAN_MASK 根据扫描作用范围生成角点掩码。
switch applyMode
    case 'all_corners'
        mask = true(4,1);
    case 'front_axle'
        mask = [true; true; false; false];
    case 'rear_axle'
        mask = [false; false; true; true];
    otherwise
        error('normalize_tire_operating_points:BadScanApplyMode', ...
            'Unsupported tireOp.scan.applyMode: %s', applyMode);
end
end

function vec = local_expand_pressure(valueIn, metaPressure, pressureUnit)
%LOCAL_EXPAND_PRESSURE 扩展 pressure；若为空则回退到 Meta pressure。
if isempty(valueIn)
    if isempty(metaPressure)
        vec = nan(4,1);
    else
        vec = repmat(double(metaPressure), 4, 1);
    end
else
    vec = local_convert_pressure(local_expand_corner_value(valueIn, 'tireOp.pressure'), pressureUnit);
end
end

function value = local_extract_meta_pressure(tireTableData)
%LOCAL_EXTRACT_META_PRESSURE 读取 Meta 中的默认 pressure。
value = [];
if isfield(tireTableData, 'meta') && isfield(tireTableData.meta, 'pressure') ...
        && ~isempty(tireTableData.meta.pressure)
    if isnumeric(tireTableData.meta.pressure)
        value = double(tireTableData.meta.pressure(1));
    else
        value = str2double(string(tireTableData.meta.pressure));
    end
    if isfield(tireTableData.meta, 'pressureUnit') && ~isempty(tireTableData.meta.pressureUnit)
        value = local_convert_pressure(value, tireTableData.meta.pressureUnit);
        value = value(1);
    end
end
end

function local_validate_pressure_contract(pressure, metaPressure)
% Pressure is metadata-only until a pressure axis is added to every table.
finitePressure = pressure(isfinite(pressure));
if isempty(finitePressure)
    return;
end
if isempty(metaPressure) || ~isfinite(metaPressure)
    error('normalize_tire_operating_points:UnsupportedPressureInput', ...
        ['pressure was supplied, but the current tire table has neither a pressure ', ...
        'dimension nor a finite reference pressure.']);
end
tolerance = max(1.0, 1e-6 * abs(metaPressure));
if any(abs(finitePressure - metaPressure) > tolerance)
    error('normalize_tire_operating_points:PressureMismatch', ...
        ['Requested pressure differs from the table reference pressure. The current ', ...
        'schema cannot interpolate pressure, so returning pressure-insensitive forces ', ...
        'would be misleading.']);
end
end

function vec = local_expand_corner_value(valueIn, fieldName)
%LOCAL_EXPAND_CORNER_VALUE 支持 scalar / axle pair / 4-corner 输入。
if isempty(valueIn)
    vec = zeros(4,1);
    return;
end
if ~isnumeric(valueIn)
    error('normalize_tire_operating_points:BadInputType', '%s must be numeric.', fieldName);
end

valueIn = double(valueIn(:));
switch numel(valueIn)
    case 1
        vec = repmat(valueIn, 4, 1);
    case 2
        vec = [valueIn(1); valueIn(1); valueIn(2); valueIn(2)];
    case 4
        vec = valueIn;
    otherwise
        error('normalize_tire_operating_points:BadInputSize', ...
            '%s must be scalar, [front rear], or [FL FR RL RR].', fieldName);
end
end

function vec = local_expand_scalar(valueIn, fieldName, nCopies)
%LOCAL_EXPAND_SCALAR 将轴级标量扩展为左右两侧同值。
if isempty(valueIn)
    valueIn = 0.0;
end
if ~(isnumeric(valueIn) && isscalar(valueIn))
    error('normalize_tire_operating_points:BadProxyScalar', '%s must be a numeric scalar.', fieldName);
end
vec = repmat(double(valueIn), nCopies, 1);
end

function out = local_convert_angle(data, unitName)
%LOCAL_CONVERT_ANGLE 角度统一转 rad。
switch local_normalize_unit_string(unitName)
    case 'deg'
        out = deg2rad(double(data(:)));
    case 'rad'
        out = double(data(:));
    otherwise
        error('normalize_tire_operating_points:BadAngleUnit', 'Unsupported angle unit: %s', unitName);
end
end

function out = local_convert_kappa(data, unitName)
%LOCAL_CONVERT_KAPPA 纵滑率统一转 ratio。
switch local_normalize_unit_string(unitName)
    case {'ratio', 'unitless'}
        out = double(data(:));
    case {'pct', 'percent'}
        out = 0.01 * double(data(:));
    otherwise
        error('normalize_tire_operating_points:BadKappaUnit', 'Unsupported kappa unit: %s', unitName);
end
end

function out = local_convert_pressure(data, unitName)
%LOCAL_CONVERT_PRESSURE 压力统一转 Pa。
switch local_normalize_unit_string(unitName)
    case 'pa'
        out = double(data(:));
    case 'kpa'
        out = 1e3 * double(data(:));
    case 'bar'
        out = 1e5 * double(data(:));
    case 'psi'
        out = 6894.757293168 * double(data(:));
    otherwise
        error('normalize_tire_operating_points:BadPressureUnit', 'Unsupported pressure unit: %s', unitName);
end
end

function unitName = local_normalize_unit_string(unitName)
%LOCAL_NORMALIZE_UNIT_STRING 统一单位字符串大小写与空白。
unitName = lower(strtrim(char(string(unitName))));
end
