function results = postprocess_results(caseDef, solveOut)
%POSTPROCESS_RESULTS 组装 V1.0.4 标准结果结构体。
% 功能说明:
%   1) 汇总求解状态、气动载荷、角点载荷与静/动态离地高。
%   2) 输出 wheel/shock/clearance 三层约束判据。
%   3) 正式区分 converged/rulePass/designPass/feasible。
%   4) 输出 wheel/tire/shock 位移语义分解、effective travel 与 bump-adjusted clearance。
%   5) 输出 spring sweep 所需的 aero/scrape pass 与四色分类字段。
%
% 输入:
%   caseDef  - 预处理后的输入结构（含 derived.susp/derived.tire/derived.bumpAdjust）
%   solveOut - solve_equilibrium 输出
%
% 输出:
%   results - 统一结果结构体
%
% 关键物理假设:
%   1) deltaSuspWheel = Fmain ./ kw
%   2) deltaTire = Fmain ./ kt（off 模式视为 0）
%   3) deltaGround = deltaSuspWheel + deltaTire
%   4) shockStroke = mr .* deltaSuspWheel
%   5) bump-adjusted clearance 是对 dynamic clearance 的保守扣减，不是新的瞬态求解器
%
% 单位约定:
%   长度[m]，角度[rad/deg]，力[N]，力矩[N*m]

q = solveOut.q(:);
if isfield(solveOut, 'ctx') && ~isempty(solveOut.ctx)
    ctx = solveOut.ctx;
else
    [~, ctx] = residual_equilibrium(caseDef, q);
end

aero = ctx.loads.aero;
corner = ctx.corner;
Qext = ctx.loads.Qext;
staticClearance = calc_static_clearance(caseDef);
dynamicClearance = calc_clearance_points(caseDef, q);
bumpAdjustedClearance = calc_bump_adjusted_clearance(caseDef, dynamicClearance);

FzStatic = caseDef.derived.FzStatic(:);
loadComp = calc_corner_load_components(caseDef, q, ctx.loads, corner);
FzDynamic = loadComp.FzDynamic;
FzTotal = FzStatic + FzDynamic;
FzAxleFront = sum(FzTotal(1:2));
FzAxleRear = sum(FzTotal(3:4));
contactLostAny = any(FzTotal <= 0);

[FzNominal, frontShareNominal, nominalValidity] = ...
    aero_nominal_reference(caseDef.aero.nominalRef, caseDef.man.V);
aeroLossCriterionDefined = ~isempty(caseDef.targets.maxAeroLossPct);
balanceCriterionDefined = ~isempty(caseDef.targets.maxFrontShareMigrationPct);
aeroCriteriaDefined = aeroLossCriterionDefined || balanceCriterionDefined;
atEvaluationSpeed = abs(caseDef.man.V) > 1e-9;
aeroLossEvaluable = aeroLossCriterionDefined && atEvaluationSpeed && ...
    nominalValidity.fzValid && FzNominal > 1e-9;
balanceEvaluable = balanceCriterionDefined && atEvaluationSpeed && ...
    nominalValidity.frontShareValid;
nominalReferenceValid = aeroCriteriaDefined && ...
    (~aeroLossCriterionDefined || aeroLossEvaluable) && ...
    (~balanceCriterionDefined || balanceEvaluable);
if nominalValidity.fzValid && FzNominal > 1e-9
    lossPct = 100 * (1 - aero.Fz / FzNominal);
elseif nominalValidity.fzValid && abs(caseDef.man.V) <= 1e-9
    lossPct = 0.0;
else
    lossPct = nan;
end
if nominalValidity.frontShareValid
    balanceMigrationPct = 100 * (aero.frontShare - frontShareNominal);
else
    balanceMigrationPct = nan;
end
aeroConsistency = assess_aero_reference_consistency(caseDef, FzNominal);

mapClampedAny = isfield(aero, 'mapClampedAny') && logical(aero.mapClampedAny);
interpFallbackUsed = isfield(aero, 'interpFallbackUsed') && logical(aero.interpFallbackUsed);
aeroOutputsFinite = all(isfinite([aero.Cz, aero.Cd, aero.Fz, aero.Drag, aero.frontShare]));
mapValidityRequired = abs(caseDef.man.V) > 1e-9;
aeroStateValid = aeroOutputsFinite && (~mapValidityRequired || ~(mapClampedAny || interpFallbackUsed));
converged = logical(solveOut.converged);
analysisReady = converged && aeroStateValid && ~contactLostAny;
classificationValid = analysisReady && aeroCriteriaDefined && nominalReferenceValid;

theta_deg = rad2deg_safe(q(2));
phi_deg = rad2deg_safe(q(3));

if abs(caseDef.man.ay) > 1e-9
    rollGradient = phi_deg / (caseDef.man.ay / caseDef.veh.g);
else
    rollGradient = 0.0;
end
if abs(caseDef.man.ax) > 1e-9
    pitchGradient = theta_deg / (abs(caseDef.man.ax) / caseDef.veh.g);
else
    pitchGradient = 0.0;
end

% ===== Wheel / Tire / Shock 位移语义分解 =====
Fmain = corner.Fmain(:);
kw = caseDef.derived.stiff.kw(:);
ktUsed = caseDef.derived.stiff.ktUsed(:);
tireMode = lower(strtrim(char(string(caseDef.derived.tire.mode))));
tireComplianceIgnored = logical(caseDef.derived.tire.tireComplianceIgnored);

% 几何层总位移（由 q 直接得到）
deltaGroundGeom = corner.delta(:);

% 悬架侧轮端位移（与轮胎柔度分离）
deltaSuspWheel = Fmain ./ max(kw, eps);

if tireComplianceIgnored
    deltaTire = zeros(4,1);
else
    deltaTire = Fmain ./ max(ktUsed, eps);
end

deltaGround = deltaSuspWheel + deltaTire;

deltaReconError = deltaGroundGeom - deltaGround;
deltaReconTol = 1e-8;
deltaReconWarning = any(abs(deltaReconError) > deltaReconTol);
if deltaReconWarning
    warning('postprocess_results:DeltaReconMismatch', ...
        'deltaGround recon mismatch exceeds tolerance %.2e (max=%.3e).', ...
        deltaReconTol, max(abs(deltaReconError)));
end

wheelJounce = max(deltaSuspWheel, 0.0);
wheelDroop = max(-deltaSuspWheel, 0.0);

effectiveJounce = caseDef.derived.susp.effectiveJounce(:);
effectiveDroop = caseDef.derived.susp.effectiveDroop(:);
effectiveTotalTravel = caseDef.derived.susp.effectiveTotalTravel(:);
minEffectiveJounce = min(effectiveJounce);
minEffectiveDroop = min(effectiveDroop);
minEffectiveTotalTravel = min(effectiveTotalTravel);

% shock 位移必须来自悬架侧轮端位移，不再使用 deltaGround
shockStroke = caseDef.sus.mr(:) .* deltaSuspWheel;

shockStrokeTotal = caseDef.derived.susp.shockStrokeTotal(:);
shockStrokeStaticUsed = caseDef.derived.susp.shockStrokeStaticUsed(:);
shockCompAvail = caseDef.derived.susp.shockCompAvail(:);
shockReboundAvail = caseDef.derived.susp.shockReboundAvail(:);

shockCurrentUsed = shockStrokeStaticUsed + shockStroke;
shockPositionPct = 100 * shockCurrentUsed ./ max(shockStrokeTotal, eps);
shockStaticPositionPct = 100 * shockStrokeStaticUsed ./ max(shockStrokeTotal, eps);
shockBiasFromMidPct = shockStaticPositionPct - 50;
shockDynamicStrokePct = 100 * abs(shockStroke) ./ max(shockStrokeTotal, eps);

shockCompMargin = shockCompAvail - shockStroke;
shockReboundMargin = shockReboundAvail + shockStroke;

wheelJounceUsagePct = 100 * wheelJounce ./ max(caseDef.sus.jounceMax(:), eps);
wheelDroopUsagePct = 100 * wheelDroop ./ max(caseDef.sus.droopMax(:), eps);
shockCompUsagePct = 100 * max(shockStroke, 0) ./ max(shockCompAvail, eps);
shockReboundUsagePct = 100 * max(-shockStroke, 0) ./ max(shockReboundAvail, eps);

% ===== violation flags =====
checkWheelTravel = logical(caseDef.solver.checkWheelTravel);
checkShockStroke = logical(caseDef.solver.checkShockStroke);

if checkWheelTravel
    wheelJounceViolation = wheelJounce > caseDef.sus.jounceMax(:);
    wheelDroopViolation = wheelDroop > caseDef.sus.droopMax(:);
else
    wheelJounceViolation = false(4,1);
    wheelDroopViolation = false(4,1);
end

if checkShockStroke
    shockCompViolation = shockCurrentUsed > shockStrokeTotal;
    shockReboundViolation = shockCurrentUsed < 0;
else
    shockCompViolation = false(4,1);
    shockReboundViolation = false(4,1);
end

wheelJounceViolationAny = any(wheelJounceViolation);
wheelDroopViolationAny = any(wheelDroopViolation);
shockCompViolationAny = any(shockCompViolation);
shockReboundViolationAny = any(shockReboundViolation);
travelViolationAny = wheelJounceViolationAny || wheelDroopViolationAny || ...
    shockCompViolationAny || shockReboundViolationAny;

% dynamic clearance<0 仍视为真实碰地风险；若 tire.mode='off'，会额外打低置信度标记。
clearanceViolation = dynamicClearance.hMin < 0;
bumpAdjustedClearanceViolation = any(bumpAdjustedClearance.values < 0);

% ===== rules 判据层：只看静态离地高 + effective travel =====
staticGroundClearanceValue = staticClearance.hMin;
usableWheelTravelValue = minEffectiveTotalTravel;
minJounceValue = minEffectiveJounce;

staticGroundClearanceMargin = staticGroundClearanceValue - caseDef.rules.minStaticGroundClearance;
usableWheelTravelMargin = usableWheelTravelValue - caseDef.rules.minUsableWheelTravelTotal;
jounceMargin = minJounceValue - caseDef.rules.minJounce;

staticGroundClearancePassRaw = staticGroundClearanceMargin >= 0;
usableWheelTravelPassRaw = usableWheelTravelMargin >= 0;
minJouncePassRaw = jounceMargin >= 0;
rulePassRaw = staticGroundClearancePassRaw && usableWheelTravelPassRaw && minJouncePassRaw;

if logical(caseDef.rules.enforceRules)
    rulePass = rulePassRaw;
else
    rulePass = true;
end

% ===== targets 判据层：只看动态离地高 + 姿态/气动窗口 =====
dynamicClearanceValue = dynamicClearance.hMin;
dynamicClearanceMargin = dynamicClearanceValue - caseDef.targets.minDynamicClearance;
dynamicClearancePassRaw = dynamicClearanceMargin >= 0;

[pitchPassRaw, pitchMargin] = optional_limit_pass(abs(theta_deg), caseDef.targets.maxPitchDeg);
[rollPassRaw, rollMargin] = optional_limit_pass(abs(phi_deg), caseDef.targets.maxRollDeg);
[aeroLossPassRaw, aeroLossMargin] = optional_limit_pass(lossPct, caseDef.targets.maxAeroLossPct);
[frontShareMigrationPassRaw, frontShareMigrationMargin] = ...
    optional_limit_pass(abs(balanceMigrationPct), caseDef.targets.maxFrontShareMigrationPct);
if aeroLossCriterionDefined && ~aeroLossEvaluable
    aeroLossPassRaw = false;
    aeroLossMargin = nan;
end
if balanceCriterionDefined && ~balanceEvaluable
    frontShareMigrationPassRaw = false;
    frontShareMigrationMargin = nan;
end

designPassRaw = dynamicClearancePassRaw && pitchPassRaw && rollPassRaw && ...
    aeroLossPassRaw && frontShareMigrationPassRaw;

if logical(caseDef.targets.enforceTargets)
    designPass = designPassRaw;
else
    designPass = true;
end

% ===== 筛选层 pass 定义 =====
aeroPlatformPassRaw = aeroLossPassRaw && frontShareMigrationPassRaw;
aeroPlatformPass = classificationValid && aeroPlatformPassRaw;
scrapePassQuasiStatic = analysisReady && ...
    staticGroundClearancePassRaw && dynamicClearancePassRaw && ~clearanceViolation;
scrapePassBumpAdjusted = analysisReady && staticGroundClearancePassRaw && ...
    bumpAdjustedClearance.dynamicPass && ~bumpAdjustedClearanceViolation;

classQuasiStatic = classify_spring_sweep_map(aeroPlatformPass, scrapePassQuasiStatic, classificationValid);
classBumpAdjusted = classify_spring_sweep_map(aeroPlatformPass, scrapePassBumpAdjusted, classificationValid);

% ===== converged / feasible 分层 =====
if logical(caseDef.solver.strictTravelViolation)
    travelGate = ~travelViolationAny && ~clearanceViolation;
else
    travelGate = true;
end

feasible = analysisReady && rulePass && designPass && travelGate;

results = struct();

results.meta = struct();
results.meta.name = caseDef.meta.name;
results.meta.version = caseDef.meta.version;
results.meta.description = caseDef.meta.description;
results.meta.author = caseDef.meta.author;
results.meta.date = caseDef.meta.date;
results.meta.runTimestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

results.inputs = caseDef;

results.state = struct();
results.state.z = q(1);
results.state.theta = q(2);
results.state.phi = q(3);
results.state.theta_deg = theta_deg;
results.state.phi_deg = phi_deg;

results.aero = struct();
results.aero.hf = aero.hf;
results.aero.hr = aero.hr;
results.aero.Cz = aero.Cz;
results.aero.Cd = aero.Cd;
results.aero.Fz = aero.Fz;
results.aero.Drag = aero.Drag;
results.aero.frontShare = aero.frontShare;
results.aero.rearShare = aero.rearShare;
results.aero.FzFront = aero.FzFront;
results.aero.FzRear = aero.FzRear;
results.aero.lossPct = lossPct;
results.aero.balanceMigrationPct = balanceMigrationPct;
results.aero.frontShareMigrationPct = balanceMigrationPct; % 兼容字段
results.aero.nominalReferenceValid = nominalReferenceValid;
results.aero.nominalReference = nominalValidity;
results.aero.criteriaDefined = aeroCriteriaDefined;
results.aero.aeroLossCriterionDefined = aeroLossCriterionDefined;
results.aero.balanceCriterionDefined = balanceCriterionDefined;
results.aero.aeroLossEvaluable = aeroLossEvaluable;
results.aero.balanceEvaluable = balanceEvaluable;
results.aero.stateValid = aeroStateValid;
results.aero.evaluationValid = classificationValid;
results.aero.maxMapFzAtSpeed = aeroConsistency.maxMapFzAtSpeed;
results.aero.minimumPossibleLossPct = aeroConsistency.minimumPossibleLossPct;
results.aero.targetLossReachableWithMap = aeroConsistency.targetLossReachableWithMap;
results.aero.mapClampedAny = mapClampedAny;
results.aero.hfClamped = isfield(aero,'hfClamped') && logical(aero.hfClamped);
results.aero.hrClamped = isfield(aero,'hrClamped') && logical(aero.hrClamped);
results.aero.phiClamped = isfield(aero,'phiClamped') && logical(aero.phiClamped);
results.aero.betaClamped = isfield(aero,'betaClamped') && logical(aero.betaClamped);
results.aero.interpFallbackUsed = interpFallbackUsed;
results.aero.evidenceStatus = char(string(caseDef.aero.evidenceStatus));
results.aero.mapSource = char(string(caseDef.aero.mapSource));
results.aero.nominalSource = char(string(caseDef.aero.nominalSource));
results.aero.mapLoadStatus = char(string(caseDef.aero.mapLoadStatus));
results.aero.mapLoadMessage = char(string(caseDef.aero.mapLoadMessage));
results.aero.nominalLoadStatus = char(string(caseDef.aero.nominalLoadStatus));
results.aero.nominalLoadMessage = char(string(caseDef.aero.nominalLoadMessage));
healthyLoadStates = {'loaded', 'provided_inline', 'not_applicable'};
results.aero.dataLoadHealthy = any(strcmpi(results.aero.mapLoadStatus, healthyLoadStates)) && ...
    any(strcmpi(results.aero.nominalLoadStatus, healthyLoadStates));
results.aero.engineeringEvidenceReady = strcmpi(results.aero.evidenceStatus, 'validated') && ...
    results.aero.dataLoadHealthy;

results.loads = struct();
results.loads.Qext = Qext;
results.loads.Mpitch = ctx.loads.Mpitch;
results.loads.Mroll = ctx.loads.Mroll;
results.loads.pitch = ctx.loads.pitch;
results.loads.roll = ctx.loads.roll;
results.loads.ayTurn = caseDef.man.ay;
results.loads.ayCartesian = -caseDef.man.ay;
results.loads.ayConvention = 'positive_left_turn_y_axis_positive_right';
results.loads.FzAxleFront = FzAxleFront;
results.loads.FzAxleRear = FzAxleRear;

results.tire = struct();
results.tire.mode = tireMode;
results.tire.ktUsed = ktUsed;
results.tire.ktCaseLabel = caseDef.derived.tire.ktCaseLabel;
results.tire.ktBand = caseDef.derived.tire.ktBand;
results.tire.tireComplianceIgnored = tireComplianceIgnored;
if tireComplianceIgnored
    results.tire.groundMetricConfidence = 'low';
else
    results.tire.groundMetricConfidence = 'normal';
end
% 轮胎代理层默认保持关闭；只有在 run_case 后处理阶段显式启用时才写入力代理结果。
results.tire.forceModel = struct( ...
    'enable', false, ...
    'sourceType', '', ...
    'mode', '', ...
    'outOfRangePolicy', '', ...
    'includeAligningMoment', false, ...
    'sourceFile', '', ...
    'dataSummary', struct());
results.tire.inputs = struct( ...
    'cornerOrder', {{'FL'; 'FR'; 'RL'; 'RR'}}, ...
    'alpha', nan(4,1), 'alphaDeg', nan(4,1), ...
    'kappa', nan(4,1), ...
    'gamma', nan(4,1), 'gammaDeg', nan(4,1), ...
    'pressure', nan(4,1), ...
    'Fz', FzTotal, ...
    'sourceType', '', ...
    'mode', '', ...
    'outOfRangePolicy', '', ...
    'dataSummary', '', ...
    'meta', struct());
results.tire.forces = struct( ...
    'Fx', nan(4,1), 'Fy', nan(4,1), 'Mz', nan(4,1), ...
    'FxRequested', nan(4,1), 'FyRequested', nan(4,1), ...
    'FxCap', nan(4,1), 'FyCap', nan(4,1));
results.tire.coeff = struct('muX', nan(4,1), 'muY', nan(4,1), 'maxAbsMuX', nan, 'maxAbsMuY', nan);
results.tire.utilization = struct( ...
    'requested', nan(4,1), 'clipped', nan(4,1), 'constraintValue', nan(4,1));
results.tire.balance = struct( ...
    'FyFrontTotal', nan, 'FyRearTotal', nan, ...
    'FxFrontTotal', nan, 'FxRearTotal', nan, ...
    'frontFyShare', nan, 'rearFyShare', nan, ...
    'frontUtilization', nan, 'rearUtilization', nan, ...
    'balanceIndex', nan, ...
    'peakMarginFront', nan, 'peakMarginRear', nan, ...
    'conditionType', strings(4,1), ...
    'usedCombinedProxyAny', false, 'usedCombinedTableAny', false);
results.tire.validity = struct( ...
    'validFz', false(4,1), 'validAlpha', false(4,1), ...
    'validKappa', false(4,1), 'validGamma', false(4,1), ...
    'outOfRange', false(4,1), 'outOfRangeAny', false, ...
    'contactLost', false(4,1), 'contactLostAny', false, ...
    'evalFailed', false, 'evaluationSkipped', false, 'wasClipped', false(4,1));
results.tire.scan = struct( ...
    'enable', false, 'field', '', 'applyMode', '', 'unit', '', ...
    'valuesRaw', zeros(0,1), 'valuesSI', zeros(0,1), ...
    'Fx', zeros(4,0), 'Fy', zeros(4,0), 'Mz', zeros(4,0), ...
    'muX', zeros(4,0), 'muY', zeros(4,0), ...
    'utilization', zeros(4,0), 'peakMargin', zeros(4,0), ...
    'FyFrontTotal', zeros(1,0), 'FyRearTotal', zeros(1,0), ...
    'FxFrontTotal', zeros(1,0), 'FxRearTotal', zeros(1,0), ...
    'balanceIndex', zeros(1,0), 'contactLostAny', false(1,0), ...
    'outOfRangeAny', false(1,0), 'cornerNames', {{'FL'; 'FR'; 'RL'; 'RR'}});

results.corners = struct();
results.corners.names = caseDef.derived.cornerNames;
results.corners.deltaGround = deltaGround;
results.corners.deltaSuspWheel = deltaSuspWheel;
results.corners.deltaTire = deltaTire;
results.corners.deltaWheel = deltaSuspWheel; % 兼容字段：明确为悬架侧轮端位移
results.corners.delta = deltaSuspWheel; % 兼容旧字段
results.corners.wheelJounce = wheelJounce;
results.corners.wheelDroop = wheelDroop;
results.corners.effectiveJounce = effectiveJounce;
results.corners.effectiveDroop = effectiveDroop;
results.corners.effectiveTotalTravel = effectiveTotalTravel;
results.corners.wheelJounceUsagePct = wheelJounceUsagePct;
results.corners.wheelDroopUsagePct = wheelDroopUsagePct;
results.corners.shockStroke = shockStroke;
results.corners.shockCurrentUsed = shockCurrentUsed;
results.corners.shockCompMargin = shockCompMargin;
results.corners.shockReboundMargin = shockReboundMargin;
results.corners.shockPositionPct = shockPositionPct;
results.corners.shockStaticPositionPct = shockStaticPositionPct;
results.corners.shockBiasFromMidPct = shockBiasFromMidPct;
results.corners.shockDynamicStrokePct = shockDynamicStrokePct;
results.corners.shockCompUsagePct = shockCompUsagePct;
results.corners.shockReboundUsagePct = shockReboundUsagePct;
results.corners.Ftotal = corner.Ftotal;
results.corners.Fmain = corner.Fmain;
results.corners.FzStatic = FzStatic;
results.corners.FzElasticSpring = loadComp.FzElasticSpring;
results.corners.FzAntiRollBar = loadComp.FzAntiRollBar;
results.corners.FzRollCenterGeometric = loadComp.FzRollCenterGeometric;
results.corners.FzAntiPitchGeometric = loadComp.FzAntiPitchGeometric;
results.corners.FzDynamic = FzDynamic;
results.corners.FzTotal = FzTotal;
% FzWheel 是 V1.5 轮胎代理层正式使用的角点法向载荷输入，来源必须是平台收敛结果。
results.corners.FzWheel = FzTotal;
results.corners.wheelJounceViolation = wheelJounceViolation;
results.corners.wheelDroopViolation = wheelDroopViolation;
results.corners.shockCompViolation = shockCompViolation;
results.corners.shockReboundViolation = shockReboundViolation;
results.corners.tireDeflection = deltaTire; % deprecated 兼容字段

results.clearance = struct();
results.clearance.names = dynamicClearance.names;
results.clearance.hAll = dynamicClearance.values;
results.clearance.hMin = dynamicClearance.hMin;
results.clearance.hMinName = dynamicClearance.hMinName;
results.clearance.hStaticAll = staticClearance.values;
results.clearance.hStaticMin = staticClearance.hMin;
results.clearance.hStaticMinName = staticClearance.hMinName;
results.clearance.hDynamicAll = dynamicClearance.values;
results.clearance.hDynamicMin = dynamicClearance.hMin;
results.clearance.hDynamicMinName = dynamicClearance.hMinName;
results.clearance.hDynamicAllBumpAdjusted = bumpAdjustedClearance.values;
results.clearance.hDynamicMinBumpAdjusted = bumpAdjustedClearance.hMin;
results.clearance.hDynamicMinBumpAdjustedName = bumpAdjustedClearance.hMinName;
results.clearance.dynamicClearanceBumpAdjustedPass = bumpAdjustedClearance.dynamicPass;
results.clearance.dynamicClearanceBumpAdjustedMargin = bumpAdjustedClearance.dynamicMargin;
results.clearance.bumpReserveByPoint = caseDef.derived.bumpAdjust.reserveByPoint;

% 兼容 V1.0/V1.0.1/V1.0.3/V1.0.3a 的 platform 字段
results.platform = struct();
results.platform.clearanceNames = dynamicClearance.names;
results.platform.clearanceValues = dynamicClearance.values;
results.platform.clearanceStaticValues = staticClearance.values;
results.platform.clearanceDynamicValues = dynamicClearance.values;
results.platform.clearanceBumpAdjustedValues = bumpAdjustedClearance.values;
results.platform.hMin = dynamicClearance.hMin;
results.platform.hMinName = dynamicClearance.hMinName;
results.platform.hStaticMin = staticClearance.hMin;
results.platform.hStaticMinName = staticClearance.hMinName;
results.platform.hDynamicMin = dynamicClearance.hMin;
results.platform.hDynamicMinName = dynamicClearance.hMinName;
results.platform.hDynamicMinBumpAdjusted = bumpAdjustedClearance.hMin;
results.platform.hDynamicMinBumpAdjustedName = bumpAdjustedClearance.hMinName;
results.platform.hf = aero.hf;
results.platform.hr = aero.hr;

results.rules = struct();
results.rules.ruleSet = caseDef.rules.ruleSet;
results.rules.staticGroundClearanceSource = caseDef.rules.staticGroundClearanceSource;
results.rules.staticGroundClearanceClause = caseDef.rules.staticGroundClearanceClause;
results.rules.staticGroundClearanceEvidenceStatus = caseDef.rules.staticGroundClearanceEvidenceStatus;
results.rules.travelConstraintSource = caseDef.rules.travelConstraintSource;
results.rules.travelConstraintClause = caseDef.rules.travelConstraintClause;
results.rules.travelEvidenceStatus = caseDef.rules.travelEvidenceStatus;
results.rules.enforceRules = logical(caseDef.rules.enforceRules);
results.rules.staticGroundClearanceValue = staticGroundClearanceValue;
results.rules.usableWheelTravelValue = usableWheelTravelValue;
results.rules.minJounceValue = minJounceValue;
results.rules.effectiveJounce = effectiveJounce;
results.rules.effectiveDroop = effectiveDroop;
results.rules.effectiveTotalTravel = effectiveTotalTravel;
results.rules.minEffectiveJounce = minEffectiveJounce;
results.rules.minEffectiveDroop = minEffectiveDroop;
results.rules.minEffectiveTotalTravel = minEffectiveTotalTravel;
results.rules.staticGroundClearancePass = staticGroundClearancePassRaw;
results.rules.usableWheelTravelPass = usableWheelTravelPassRaw;
results.rules.minJouncePass = minJouncePassRaw;
results.rules.rulePassRaw = rulePassRaw;
results.rules.rulePass = rulePass;
results.rules.staticGroundClearanceMargin = staticGroundClearanceMargin;
results.rules.usableWheelTravelMargin = usableWheelTravelMargin;
results.rules.jounceMargin = jounceMargin;

results.targets = struct();
results.targets.enforceTargets = logical(caseDef.targets.enforceTargets);
results.targets.dynamicClearanceValue = dynamicClearanceValue;
results.targets.dynamicClearancePass = dynamicClearancePassRaw;
results.targets.pitchPass = pitchPassRaw;
results.targets.rollPass = rollPassRaw;
results.targets.aeroLossPass = aeroLossPassRaw;
results.targets.frontShareMigrationPass = frontShareMigrationPassRaw;
results.targets.designPassRaw = designPassRaw;
results.targets.designPass = designPass;
results.targets.dynamicClearanceMargin = dynamicClearanceMargin;
results.targets.pitchMargin = pitchMargin;
results.targets.rollMargin = rollMargin;
results.targets.aeroLossMargin = aeroLossMargin;
results.targets.frontShareMigrationMargin = frontShareMigrationMargin;

results.metrics = struct();
results.metrics.rollGradient_deg_per_g = rollGradient;
results.metrics.pitchGradient_deg_per_g = pitchGradient;
results.metrics.frontLoadShareDynamic = FzAxleFront / (FzAxleFront + FzAxleRear);
results.metrics.rearLoadShareDynamic = FzAxleRear / (FzAxleFront + FzAxleRear);
results.metrics.dF_LR_front = FzTotal(2) - FzTotal(1);
results.metrics.dF_LR_rear = FzTotal(4) - FzTotal(3);
results.metrics.maxWheelJounceUsagePct = max(wheelJounceUsagePct);
results.metrics.maxWheelDroopUsagePct = max(wheelDroopUsagePct);
results.metrics.maxShockCompUsagePct = max(shockCompUsagePct);
results.metrics.maxShockReboundUsagePct = max(shockReboundUsagePct);
results.metrics.minShockCompMargin = min(shockCompMargin);
results.metrics.minShockReboundMargin = min(shockReboundMargin);
results.metrics.maxShockPositionPct = max(shockPositionPct);
results.metrics.maxShockDynamicStrokePct = max(shockDynamicStrokePct);
results.metrics.shockStaticPositionPct = mean(shockStaticPositionPct);
results.metrics.shockBiasFromMidPct = mean(shockBiasFromMidPct);
results.metrics.hStaticMin = staticClearance.hMin;
results.metrics.hDynamicMin = dynamicClearance.hMin;
results.metrics.hDynamicMinBumpAdjusted = bumpAdjustedClearance.hMin;
results.metrics.minEffectiveJounce = minEffectiveJounce;
results.metrics.minEffectiveDroop = minEffectiveDroop;
results.metrics.minEffectiveTotalTravel = minEffectiveTotalTravel;
results.metrics.bumpReserveFront = caseDef.derived.bumpAdjust.reserveFront;
results.metrics.bumpReserveRear = caseDef.derived.bumpAdjust.reserveRear;
results.metrics.balanceIndex = nan;
results.metrics.peakMarginFront = nan;
results.metrics.peakMarginRear = nan;
results.metrics.maxAbsMuX = nan;
results.metrics.maxAbsMuY = nan;

results.flags = struct();
results.flags.converged = converged;
results.flags.rulePass = rulePass;
results.flags.designPass = designPass;
results.flags.feasible = feasible;
results.flags.platformFeasible = feasible;
results.flags.analysisReady = analysisReady;
% The reviewed model still has documented architecture/data closure gaps.
% Keep the top-level engineering gate fail-closed until those gates exist
% as machine-verifiable inputs rather than user-editable status strings.
results.flags.engineeringReady = false;
results.flags.engineeringReadinessStatus = 'not_ready_model_scope';
results.flags.decisionInvalidReason = '';
results.flags.classificationValid = classificationValid;
results.flags.aeroStateValid = aeroStateValid;
results.flags.nominalReferenceValid = nominalReferenceValid;
results.flags.wheelJounceViolationAny = wheelJounceViolationAny;
results.flags.wheelDroopViolationAny = wheelDroopViolationAny;
results.flags.shockCompViolationAny = shockCompViolationAny;
results.flags.shockReboundViolationAny = shockReboundViolationAny;
results.flags.travelViolationAny = travelViolationAny;
results.flags.clearanceViolation = clearanceViolation;
results.flags.bumpAdjustedClearanceViolation = bumpAdjustedClearanceViolation;
results.flags.tireComplianceIgnored = tireComplianceIgnored;
results.flags.groundReferencedLowConfidence = tireComplianceIgnored;
results.flags.shockWheelConsistencyWarning = logical(caseDef.derived.susp.shockWheelConsistencyWarning);
results.flags.deltaReconWarning = deltaReconWarning;
results.flags.mapClampedAny = results.aero.mapClampedAny;
results.flags.mapClamped = results.aero.mapClampedAny; % 兼容字段
results.flags.hfClamped = results.aero.hfClamped;
results.flags.hrClamped = results.aero.hrClamped;
results.flags.phiClamped = results.aero.phiClamped;
results.flags.betaClamped = results.aero.betaClamped;
results.flags.interpFallbackUsed = results.aero.interpFallbackUsed;
results.flags.aeroPlatformPass = aeroPlatformPass;
results.flags.aeroPlatformPassRaw = aeroPlatformPassRaw;
results.flags.scrapePassQuasiStatic = scrapePassQuasiStatic;
results.flags.scrapePassBumpAdjusted = scrapePassBumpAdjusted;
results.flags.mapClassQuasiStatic = classQuasiStatic.classCode;
results.flags.mapClassQuasiStaticLabel = classQuasiStatic.classLabel;
results.flags.mapClassQuasiStaticColor = classQuasiStatic.colorArray;
results.flags.mapClassBumpAdjusted = classBumpAdjusted.classCode;
results.flags.mapClassBumpAdjustedLabel = classBumpAdjusted.classLabel;
results.flags.mapClassBumpAdjustedColor = classBumpAdjusted.colorArray;
results.flags.tireForceModelEnabled = false;
results.flags.tireEvalFailed = false;
results.flags.tireEvaluationSkipped = false;
results.flags.tireOutOfRange = false;
results.flags.contactLostAny = contactLostAny;
if isfield(caseDef, 'validation') && isfield(caseDef.validation, 'badInput')
    results.flags.badInput = logical(caseDef.validation.badInput);
else
    results.flags.badInput = false;
end

results.debug = struct();
results.debug.iterHistory = solveOut.iterHistory;
results.debug.residualHistory = solveOut.residualHistory;
results.debug.normalizedResidualHistory = solveOut.normalizedResidualHistory;
results.debug.lastResidual = solveOut.lastResidual;
results.debug.lastNormalizedResidual = solveOut.lastNormalizedResidual;
results.debug.message = solveOut.message;
results.debug.errorIdentifier = '';
results.debug.failureStage = '';
if isfield(solveOut, 'solverUsed')
    results.debug.solverUsed = solveOut.solverUsed;
else
    results.debug.solverUsed = 'unknown';
end
if isfield(aero, 'mapClampInfo')
    results.debug.mapClampInfo = aero.mapClampInfo;
else
    results.debug.mapClampInfo = struct();
end
results.debug.validation = struct();
results.debug.validation.deltaReconError = deltaReconError;
results.debug.validation.deltaReconTol = deltaReconTol;
results.debug.validation.deltaGroundGeom = deltaGroundGeom;
results.debug.validation.deltaGroundReconstructed = deltaGround;
results.debug.validation.wheelJounceFromShock = caseDef.derived.susp.wheelJounceFromShock;
results.debug.validation.wheelDroopFromShock = caseDef.derived.susp.wheelDroopFromShock;
results.debug.validation.bumpReserveByPoint = caseDef.derived.bumpAdjust.reserveByPoint;
results.debug.validation.contactLoadGeneralized = caseDef.derived.geom.V' * FzDynamic;
results.debug.validation.contactLoadAssumptions = loadComp.assumptions;
end

function assessment = assess_aero_reference_consistency(caseDef, FzNominal)
%ASSESS_AERO_REFERENCE_CONSISTENCY Quantify whether the map can reach the target.
assessment = struct('maxMapFzAtSpeed', nan, 'minimumPossibleLossPct', nan, ...
    'targetLossReachableWithMap', false);
if abs(caseDef.man.V) <= 1e-9
    assessment.maxMapFzAtSpeed = 0;
    assessment.minimumPossibleLossPct = 0;
    assessment.targetLossReachableWithMap = true;
    return;
end
if ~strcmpi(caseDef.aero.mapType, 'table_lookup') || ...
        ~isfield(caseDef.aero.mapData, 'CzTable') || ...
        ~isfinite(FzNominal) || FzNominal <= 0
    return;
end
CzFinite = caseDef.aero.mapData.CzTable(isfinite(caseDef.aero.mapData.CzTable));
if isempty(CzFinite)
    return;
end
assessment.maxMapFzAtSpeed = 0.5 * caseDef.aero.rho * caseDef.man.V^2 * ...
    caseDef.aero.Aref * max(CzFinite);
assessment.minimumPossibleLossPct = 100 * ...
    (1 - assessment.maxMapFzAtSpeed / FzNominal);
if isempty(caseDef.targets.maxAeroLossPct)
    assessment.targetLossReachableWithMap = true;
else
    assessment.targetLossReachableWithMap = ...
        assessment.minimumPossibleLossPct <= caseDef.targets.maxAeroLossPct;
end
end

function [pass, margin] = optional_limit_pass(value, limit)
%OPTIONAL_LIMIT_PASS 可选上限约束判定。
if isempty(limit)
    pass = true;
    margin = inf;
else
    margin = limit - value;
    pass = margin >= 0;
end
end

function clearance = calc_static_clearance(caseDef)
%CALC_STATIC_CLEARANCE 计算静态安装点离地高。
values = caseDef.ref.hClear0(:);
[hMin, idxMin] = min(values);
clearance = struct();
clearance.names = caseDef.ref.nameClear(:);
clearance.values = values;
clearance.hMin = hMin;
clearance.hMinName = clearance.names{idxMin};
end

function clearance = calc_bump_adjusted_clearance(caseDef, dynamicClearance)
%CALC_BUMP_ADJUSTED_CLEARANCE 对 dynamic clearance 施加保守 bump 扣减。
reserveByPoint = caseDef.derived.bumpAdjust.reserveByPoint(:);
values = dynamicClearance.values(:) - reserveByPoint;
[hMin, idxMin] = min(values);
dynamicMargin = hMin - caseDef.targets.minDynamicClearance;
clearance = struct();
clearance.names = dynamicClearance.names;
clearance.values = values;
clearance.hMin = hMin;
clearance.hMinName = clearance.names{idxMin};
clearance.dynamicPass = dynamicMargin >= 0;
clearance.dynamicMargin = dynamicMargin;
end
