function tireEval = evaluate_tire_table_model(caseDef, tireTableData, tireOpNorm)
%EVALUATE_TIRE_TABLE_MODEL 评估 V1.5 轮胎代理层四角点 Fx/Fy/Mz。
% 功能说明:
%   1) 接收平台耦合后的 Fz 与归一化 operating point。
%   2) 使用 pure Fy/Fx/Mz 表进行插值，并在需要时调用 combined proxy。
%   3) 输出四角点轮胎力、利用率、峰值余量、有效性与可选 scan 结果。
%
% 输入:
%   caseDef       - 顶层输入结构（使用 tire.forceModel.*）
%   tireTableData - load_tire_table_data 输出
%   tireOpNorm    - normalize_tire_operating_points 输出
%
% 输出:
%   tireEval - 统一轮胎评估结果结构
%
% 关键物理假设:
%   1) Fz 必须来自平台收敛结果，而不是用户重复手填另一套角点载荷。
%   2) 纯侧偏 / 纯纵滑能力来自表格代理层。
%   3) combined 工况若没有 combined 表，则由显式 combined proxy 近似，不等价于完整 MF。
%
% 单位约定:
%   alpha/gamma [rad]，kappa [-]，Fz/Fx/Fy [N]，Mz [N*m]

forceModel = caseDef.tire.forceModel;
policy = strtrim(char(string(forceModel.outOfRangePolicy)));

[baseEval, outOfRangeEvents] = local_evaluate_operating_points(caseDef, tireTableData, tireOpNorm);

scanOut = struct( ...
    'enable', false, ...
    'field', '', ...
    'applyMode', '', ...
    'unit', '', ...
    'valuesRaw', zeros(0,1), ...
    'valuesSI', zeros(0,1), ...
    'Fx', zeros(4,0), ...
    'Fy', zeros(4,0), ...
    'Mz', zeros(4,0), ...
    'muX', zeros(4,0), ...
    'muY', zeros(4,0), ...
    'utilization', zeros(4,0), ...
    'peakMargin', zeros(4,0), ...
    'FyFrontTotal', zeros(1,0), ...
    'FyRearTotal', zeros(1,0), ...
    'FxFrontTotal', zeros(1,0), ...
    'FxRearTotal', zeros(1,0), ...
    'balanceIndex', zeros(1,0), ...
    'contactLostAny', false(1,0), ...
    'outOfRangeAny', false(1,0));

if isfield(tireOpNorm, 'scan') && isstruct(tireOpNorm.scan) && logical(tireOpNorm.scan.enable)
    [scanOut, scanEvents] = local_evaluate_scan(caseDef, tireTableData, tireOpNorm);
    outOfRangeEvents = outOfRangeEvents || scanEvents;
end

if outOfRangeEvents && strcmpi(policy, 'warn_clamp')
    warning('evaluate_tire_table_model:OutOfRange', ...
        ['Tire table query exceeded available data range and was clamped. ', ...
         'Check tire.forceModel.outOfRangePolicy or expand the source table.']);
end

tireEval = baseEval;
tireEval.scan = scanOut;
end

function [evalOut, outOfRangeAny] = local_evaluate_operating_points(caseDef, tireTableData, tireOpNorm)
%LOCAL_EVALUATE_OPERATING_POINTS 对单个四角点 operating point 做轮胎评估。
forceModel = caseDef.tire.forceModel;
combinedMode = lower(strtrim(char(string(forceModel.mode))));
includeMz = logical(forceModel.includeAligningMoment);

nCorner = 4;
Fx = nan(nCorner, 1);
Fy = nan(nCorner, 1);
Mz = nan(nCorner, 1);
FxRequested = nan(nCorner, 1);
FyRequested = nan(nCorner, 1);

FxCapUsed = nan(nCorner, 1);
FyCapUsed = nan(nCorner, 1);
utilization = nan(nCorner, 1);
utilizationDemand = nan(nCorner, 1);
constraintValue = nan(nCorner, 1);
peakMargin = nan(nCorner, 1);
usedCombinedProxy = false(nCorner, 1);
usedCombinedTable = false(nCorner, 1);
wasClipped = false(nCorner, 1);
conditionType = strings(nCorner, 1);

validFz = isfinite(tireOpNorm.Fz(:)) & (tireOpNorm.Fz(:) > 0);
validAlpha = isfinite(tireOpNorm.alpha(:));
validKappa = isfinite(tireOpNorm.kappa(:));
validGamma = isfinite(tireOpNorm.gamma(:));
contactLost = ~validFz;
outOfRangeMask = false(nCorner, 1);

for i = 1:nCorner
    if ~(validFz(i) && validAlpha(i) && validKappa(i) && validGamma(i))
        continue;
    end

    alpha = tireOpNorm.alpha(i);
    kappa = tireOpNorm.kappa(i);
    gamma = tireOpNorm.gamma(i);
    Fz = tireOpNorm.Fz(i);

    [FyPure, fyInfo] = local_eval_scalar_model(tireTableData.tables.Fy, [alpha, Fz, gamma], ...
        forceModel.outOfRangePolicy, 'FyTable');
    [FxPure, fxInfo] = local_eval_scalar_model(tireTableData.tables.Fx, [kappa, Fz, gamma], ...
        forceModel.outOfRangePolicy, 'FxTable');

    if includeMz && ~isempty(tireTableData.tables.Mz)
        [MzPure, mzInfo] = local_eval_scalar_model(tireTableData.tables.Mz, [alpha, Fz, gamma], ...
            forceModel.outOfRangePolicy, 'MzTable');
    else
        MzPure = 0.0;
        mzInfo = local_empty_eval_info();
    end

    [FyCap, fyCapInfo] = local_eval_capability(tireTableData.capability.FyAbs, [Fz, gamma], ...
        forceModel.outOfRangePolicy, 'FyCap');
    [FxCapAbs, fxCapInfo] = local_eval_capability(tireTableData.capability.FxAbs, [Fz, gamma], ...
        forceModel.outOfRangePolicy, 'FxCap');
    [FxCapBrake, fxBrakeInfo] = local_eval_capability(tireTableData.capability.FxBrake, [Fz, gamma], ...
        forceModel.outOfRangePolicy, 'FxCapBrake');
    [FxCapTraction, fxTractionInfo] = local_eval_capability(tireTableData.capability.FxTraction, [Fz, gamma], ...
        forceModel.outOfRangePolicy, 'FxCapTraction');

    if logical(forceModel.combinedProxy.useSeparateBrakeTraction) && kappa < 0
        FxCap = FxCapBrake;
    elseif logical(forceModel.combinedProxy.useSeparateBrakeTraction) && kappa > 0
        FxCap = FxCapTraction;
    else
        FxCap = FxCapAbs;
    end
    FxCap = max(FxCap, eps);
    FyCap = max(FyCap, eps);

    outOfRangeMask(i) = fyInfo.outOfRangeAny || fxInfo.outOfRangeAny || mzInfo.outOfRangeAny || ...
        fyCapInfo.outOfRangeAny || fxCapInfo.outOfRangeAny || fxBrakeInfo.outOfRangeAny || fxTractionInfo.outOfRangeAny;
    FxRequested(i) = FxPure;
    FyRequested(i) = FyPure;
    FxCapUsed(i) = FxCap;
    FyCapUsed(i) = FyCap;

    isPureLateral = abs(kappa) <= 1e-12;
    isPureLongitudinal = abs(alpha) <= 1e-12;

    if isPureLateral
        conditionType(i) = "pure_lateral";
        Fx(i) = FxPure;
        Fy(i) = FyPure;
        Mz(i) = MzPure;
        utilizationDemand(i) = abs(FyPure) / FyCap;
        constraintValue(i) = utilizationDemand(i) .^ forceModel.combinedProxy.exponent;
        utilization(i) = min(utilizationDemand(i), 1.0);
        peakMargin(i) = 1.0 - utilizationDemand(i);

    elseif isPureLongitudinal
        conditionType(i) = "pure_longitudinal";
        Fx(i) = FxPure;
        Fy(i) = FyPure;
        Mz(i) = MzPure;
        utilizationDemand(i) = abs(FxPure) / FxCap;
        constraintValue(i) = utilizationDemand(i) .^ forceModel.combinedProxy.exponent;
        utilization(i) = min(utilizationDemand(i), 1.0);
        peakMargin(i) = 1.0 - utilizationDemand(i);

    else
        if kappa < 0
            conditionType(i) = "combined_brake";
        else
            conditionType(i) = "combined_drive";
        end

        if ~isempty(tireTableData.tables.Combined)
            combined = tireTableData.tables.Combined;
            [FxComb, combFxInfo] = local_eval_combined_model(combined, [alpha, kappa, Fz, gamma], ...
                forceModel.outOfRangePolicy, 'CombinedTable.Fx', 'Fx');
            [FyComb, combFyInfo] = local_eval_combined_model(combined, [alpha, kappa, Fz, gamma], ...
                forceModel.outOfRangePolicy, 'CombinedTable.Fy', 'Fy');
            if includeMz && ~isempty(combined.interpolantMz)
                [MzComb, combMzInfo] = local_eval_combined_model(combined, [alpha, kappa, Fz, gamma], ...
                    forceModel.outOfRangePolicy, 'CombinedTable.Mz', 'Mz');
            else
                MzComb = 0.0;
                combMzInfo = local_empty_eval_info();
            end

            outOfRangeMask(i) = outOfRangeMask(i) || ...
                combFxInfo.outOfRangeAny || combFyInfo.outOfRangeAny || combMzInfo.outOfRangeAny;
            usedCombinedTable(i) = true;
            Fx(i) = FxComb;
            Fy(i) = FyComb;
            Mz(i) = MzComb;
            constraintValue(i) = (abs(FxComb) / FxCap) .^ forceModel.combinedProxy.exponent + ...
                (abs(FyComb) / FyCap) .^ forceModel.combinedProxy.exponent;
            utilizationDemand(i) = constraintValue(i) .^ (1.0 / forceModel.combinedProxy.exponent);
            utilization(i) = min(utilizationDemand(i), 1.0);
            peakMargin(i) = 1.0 - utilizationDemand(i);

        else
            switch combinedMode
                case 'pure_plus_combined_proxy'
                    if ~logical(forceModel.combinedProxy.enable)
                        error('evaluate_tire_table_model:CombinedProxyDisabled', ...
                            'Combined tire state requested, but combinedProxy.enable=false and no CombinedTable is available.');
                    end
                    proxy = evaluate_tire_combined_proxy(FxPure, FyPure, FxCap, FyCap, forceModel.combinedProxy);
                    usedCombinedProxy(i) = true;
                    wasClipped(i) = proxy.wasClipped;
                    Fx(i) = proxy.clippedFx;
                    Fy(i) = proxy.clippedFy;
                    Mz(i) = MzPure * proxy.scale;
                    utilization(i) = proxy.utilization;
                    utilizationDemand(i) = proxy.utilizationDemand;
                    constraintValue(i) = proxy.constraintValue;
                    peakMargin(i) = proxy.peakMargin;

                case 'pure_tables'
                    error('evaluate_tire_table_model:CombinedUnavailable', ...
                        ['Combined tire state requested, but forceModel.mode=pure_tables and no ', ...
                         'CombinedTable is available.']);

                otherwise
                    error('evaluate_tire_table_model:BadForceMode', ...
                        'Unsupported tire.forceModel.mode: %s', combinedMode);
            end
        end
    end
end

outOfRangeAny = any(outOfRangeMask);

evalOut = struct();
evalOut.cornerNames = tireOpNorm.cornerNames;
evalOut.alpha = tireOpNorm.alpha(:);
evalOut.kappa = tireOpNorm.kappa(:);
evalOut.gamma = tireOpNorm.gamma(:);
evalOut.pressure = tireOpNorm.pressure(:);
evalOut.Fz = tireOpNorm.Fz(:);
evalOut.Fx = Fx;
evalOut.Fy = Fy;
evalOut.Mz = Mz;
evalOut.FxRequested = FxRequested;
evalOut.FyRequested = FyRequested;
evalOut.FxCap = FxCapUsed;
evalOut.FyCap = FyCapUsed;
evalOut.utilization = utilization;
evalOut.utilizationDemand = utilizationDemand;
evalOut.constraintValue = constraintValue;
evalOut.peakMargin = peakMargin;
evalOut.usedCombinedProxy = usedCombinedProxy;
evalOut.usedCombinedTable = usedCombinedTable;
evalOut.wasClipped = wasClipped;
evalOut.conditionType = conditionType;
evalOut.validity = struct();
evalOut.validity.validFz = validFz;
evalOut.validity.validAlpha = validAlpha;
evalOut.validity.validKappa = validKappa;
evalOut.validity.validGamma = validGamma;
evalOut.validity.outOfRange = outOfRangeMask;
evalOut.validity.outOfRangeAny = outOfRangeAny;
evalOut.validity.contactLost = contactLost;
evalOut.validity.contactLostAny = any(contactLost);
evalOut.validity.evalFailed = false;
end

function [scanOut, outOfRangeAny] = local_evaluate_scan(caseDef, tireTableData, tireOpNorm)
%LOCAL_EVALUATE_SCAN 沿指定 axis 扫描 operating point 并保留结果。
scanCfg = tireOpNorm.scan;
nScan = numel(scanCfg.valuesSI);

Fx = nan(4, nScan);
Fy = nan(4, nScan);
Mz = nan(4, nScan);
muX = nan(4, nScan);
muY = nan(4, nScan);
utilization = nan(4, nScan);
peakMargin = nan(4, nScan);
FyFrontTotal = nan(1, nScan);
FyRearTotal = nan(1, nScan);
FxFrontTotal = nan(1, nScan);
FxRearTotal = nan(1, nScan);
balanceIndex = nan(1, nScan);
contactLostAny = false(1, nScan);
outOfRangeTrack = false(1, nScan);

for i = 1:nScan
    opI = tireOpNorm;
    opI.scan = struct('enable', false);
    switch scanCfg.field
        case 'alpha'
            opI.alpha(scanCfg.mask) = scanCfg.valuesSI(i);
        case 'kappa'
            opI.kappa(scanCfg.mask) = scanCfg.valuesSI(i);
        case 'gamma'
            opI.gamma(scanCfg.mask) = scanCfg.valuesSI(i);
        case 'pressure'
            opI.pressure(scanCfg.mask) = scanCfg.valuesSI(i);
    end

    [evalI, outFlagI] = local_evaluate_operating_points(caseDef, tireTableData, opI);
    Fx(:, i) = evalI.Fx;
    Fy(:, i) = evalI.Fy;
    Mz(:, i) = evalI.Mz;
    muX(:, i) = evalI.Fx ./ max(evalI.Fz, eps);
    muY(:, i) = evalI.Fy ./ max(evalI.Fz, eps);
    utilization(:, i) = evalI.utilizationDemand;
    peakMargin(:, i) = evalI.peakMargin;
    FyFrontTotal(i) = sum(evalI.Fy(1:2), 'omitnan');
    FyRearTotal(i) = sum(evalI.Fy(3:4), 'omitnan');
    FxFrontTotal(i) = sum(evalI.Fx(1:2), 'omitnan');
    FxRearTotal(i) = sum(evalI.Fx(3:4), 'omitnan');
    frontUtil = max(evalI.utilization(1:2), [], 'omitnan');
    rearUtil = max(evalI.utilization(3:4), [], 'omitnan');
    balanceIndex(i) = frontUtil - rearUtil;
    contactLostAny(i) = evalI.validity.contactLostAny;
    outOfRangeTrack(i) = outFlagI;
end

scanOut = struct();
scanOut.enable = true;
scanOut.field = scanCfg.field;
scanOut.applyMode = scanCfg.applyMode;
scanOut.unit = scanCfg.unit;
scanOut.valuesRaw = scanCfg.valuesRaw(:);
scanOut.valuesSI = scanCfg.valuesSI(:);
scanOut.Fx = Fx;
scanOut.Fy = Fy;
scanOut.Mz = Mz;
scanOut.muX = muX;
scanOut.muY = muY;
scanOut.utilization = utilization;
scanOut.peakMargin = peakMargin;
scanOut.FyFrontTotal = FyFrontTotal;
scanOut.FyRearTotal = FyRearTotal;
scanOut.FxFrontTotal = FxFrontTotal;
scanOut.FxRearTotal = FxRearTotal;
scanOut.balanceIndex = balanceIndex;
scanOut.contactLostAny = contactLostAny;
scanOut.outOfRangeAny = outOfRangeTrack;
scanOut.cornerNames = tireOpNorm.cornerNames;
outOfRangeAny = any(outOfRangeTrack);
end

function [value, info] = local_eval_scalar_model(model, query, policy, label)
%LOCAL_EVAL_SCALAR_MODEL 按策略执行 2D/3D 插值与越界处理。
if isempty(model)
    error('evaluate_tire_table_model:MissingModel', '%s is not available in tire table data.', label);
end
info = local_empty_eval_info();

[queryUsed, info.outOfRangeAny] = local_apply_policy(query, model.minValues, model.maxValues, policy);
if strcmpi(policy, 'nan') && info.outOfRangeAny
    value = nan;
    return;
end

value = local_call_interpolant(model.interpolant, queryUsed);
end

function [value, info] = local_eval_capability(model, query, policy, label)
%LOCAL_EVAL_CAPABILITY 评估 2D 峰值能力表；若模型缺失则返回 eps。
info = local_empty_eval_info();
if isempty(model)
    value = eps;
    return;
end

[queryUsed, info.outOfRangeAny] = local_apply_policy(query, model.minValues, model.maxValues, policy);
if strcmpi(policy, 'error') && info.outOfRangeAny
    error('evaluate_tire_table_model:CapabilityOutOfRange', ...
        '%s query is out of range and outOfRangePolicy=error.', label);
end
if strcmpi(policy, 'nan') && info.outOfRangeAny
    value = nan;
    return;
end

value = local_call_interpolant(model.interpolant, queryUsed);
end

function [value, info] = local_eval_combined_model(model, query, policy, label, outputTag)
%LOCAL_EVAL_COMBINED_MODEL 评估 4D CombinedTable。
info = local_empty_eval_info();
[queryUsed, info.outOfRangeAny] = local_apply_policy(query, model.minValues, model.maxValues, policy);
if strcmpi(policy, 'nan') && info.outOfRangeAny
    value = nan;
    return;
end

switch lower(outputTag)
    case 'fx'
        value = local_call_interpolant(model.interpolantFx, queryUsed);
    case 'fy'
        value = local_call_interpolant(model.interpolantFy, queryUsed);
    case 'mz'
        if isempty(model.interpolantMz)
            value = 0.0;
        else
            value = local_call_interpolant(model.interpolantMz, queryUsed);
        end
    otherwise
        error('evaluate_tire_table_model:BadCombinedOutput', ...
            'Unsupported combined output tag: %s (%s).', outputTag, label);
end
end

function [queryUsed, outOfRangeAny] = local_apply_policy(query, minValues, maxValues, policy)
%LOCAL_APPLY_POLICY 根据 outOfRangePolicy 对查询点执行 clamp/error/nan。
query = double(query(:)).';
minValues = double(minValues(:)).';
maxValues = double(maxValues(:)).';

outOfRangeAny = any(query < minValues) || any(query > maxValues);
switch lower(strtrim(char(string(policy))))
    case 'warn_clamp'
        queryUsed = min(max(query, minValues), maxValues);
    case 'error'
        if outOfRangeAny
            error('evaluate_tire_table_model:OutOfRangeError', ...
                'Tire table query is outside the available data range.');
        end
        queryUsed = query;
    case 'nan'
        queryUsed = query;
    otherwise
        error('evaluate_tire_table_model:BadPolicy', ...
            'Unsupported tire.forceModel.outOfRangePolicy: %s', policy);
end
end

function value = local_call_interpolant(interpolantObj, query)
%LOCAL_CALL_INTERPOLANT 统一调用 2D/3D/4D interpolant。
nq = numel(query);
switch nq
    case 2
        value = interpolantObj(query(1), query(2));
    case 3
        value = interpolantObj(query(1), query(2), query(3));
    case 4
        value = interpolantObj(query(1), query(2), query(3), query(4));
    otherwise
        error('evaluate_tire_table_model:BadQueryDim', 'Unsupported interpolant query dimension: %d', nq);
end
end

function info = local_empty_eval_info()
%LOCAL_EMPTY_EVAL_INFO 构造空的评估信息结构。
info = struct('outOfRangeAny', false);
end
