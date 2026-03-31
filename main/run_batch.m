function batchResults = run_batch(caseArray, options)
%RUN_BATCH 批量运行多个 caseDef 并输出方案筛选汇总表（V1.0.4）。
% 功能说明:
%   保持 run_batch(caseArray, options) 接口不变，扩展 summaryTable 字段，
%   支持 static/dynamic clearance、bump-adjusted scrape、effective travel、
%   aero/scrape pass 与 spring sweep 分类筛选。
%
% 输入:
%   caseArray - struct array 或 cell array（每个元素为 caseDef）
%   options   - 传递给 run_case
%
% 输出:
%   batchResults.resultsList
%   batchResults.nCases
%   batchResults.nConverged
%   batchResults.nFeasible
%   batchResults.summaryTable

if nargin < 2
    options = struct();
end

if isstruct(caseArray)
    caseCell = arrayfun(@(s) s, caseArray, 'UniformOutput', false);
elseif iscell(caseArray)
    caseCell = caseArray;
else
    error('run_batch:BadInput', 'caseArray must be struct array or cell array.');
end

n = numel(caseCell);
resultsList = cell(n, 1);

Name = strings(n, 1);
Converged = false(n, 1);
RulePass = false(n, 1);
DesignPass = false(n, 1);
Feasible = false(n, 1);

FrontSpring = nan(n, 1);
RearSpring = nan(n, 1);
Z_mm = nan(n, 1);
Theta_deg = nan(n, 1);
Phi_deg = nan(n, 1);
Hf_mm = nan(n, 1);
Hr_mm = nan(n, 1);
AeroLoad_N = nan(n, 1);
Drag_N = nan(n, 1);
LossPct = nan(n, 1);
FrontShare = nan(n, 1);
FrontShareMigrationPct = nan(n, 1);

hStaticMin = nan(n, 1);
hStaticMin_mm = nan(n, 1);
hDynamicMin = nan(n, 1);
hDynamicMin_mm = nan(n, 1);
hDynamicMinBumpAdjusted = nan(n, 1);
hDynamicMinBumpAdjusted_mm = nan(n, 1);
hMin = nan(n, 1);
hMin_mm = nan(n, 1);

StaticGroundClearancePass = false(n, 1);
DynamicClearancePass = false(n, 1);
DynamicClearanceBumpAdjustedPass = false(n, 1);
AeroPlatformPass = false(n, 1);
ScrapePassQuasiStatic = false(n, 1);
ScrapePassBumpAdjusted = false(n, 1);
mapClassQuasiStatic = nan(n, 1);
mapClassBumpAdjusted = nan(n, 1);
mapLabelQuasiStatic = strings(n, 1);
mapLabelBumpAdjusted = strings(n, 1);
aeroLossPass = false(n, 1);
frontShareMigrationPass = false(n, 1);

EffectiveJounce = nan(n, 1);
EffectiveJounce_mm = nan(n, 1);
EffectiveDroop = nan(n, 1);
EffectiveDroop_mm = nan(n, 1);
EffectiveTotalTravel = nan(n, 1);
EffectiveTotalTravel_mm = nan(n, 1);

TravelViolation = false(n, 1);
ClearanceViolation = false(n, 1);
BumpAdjustedClearanceViolation = false(n, 1);
ShockCompViolation = false(n, 1);
ShockReboundViolation = false(n, 1);

MaxWheelJounceUsagePct = nan(n, 1);
MaxWheelDroopUsagePct = nan(n, 1);
MaxShockCompUsagePct = nan(n, 1);
MaxShockReboundUsagePct = nan(n, 1);
MinShockCompMargin_mm = nan(n, 1);
MinShockReboundMargin_mm = nan(n, 1);

ShockStaticPositionPct = nan(n, 1);
ShockBiasFromMidPct = nan(n, 1);
BumpReserveFront = nan(n, 1);
BumpReserveRear = nan(n, 1);

TireMode = strings(n, 1);
KtCase = strings(n, 1);
KtBand = strings(n, 1);

tireEvalFailed = false(n, 1);
tireOutOfRange = false(n, 1);
contactLostAny = false(n, 1);
FyFrontTotal = nan(n, 1);
FyRearTotal = nan(n, 1);
FxFrontTotal = nan(n, 1);
FxRearTotal = nan(n, 1);
frontFyShare = nan(n, 1);
rearFyShare = nan(n, 1);
balanceIndex = nan(n, 1);
peakMarginFront = nan(n, 1);
peakMarginRear = nan(n, 1);
maxAbsMuY = nan(n, 1);
maxAbsMuX = nan(n, 1);

for i = 1:n
    res = run_case(caseCell{i}, options);
    resultsList{i} = res;

    Name(i) = string(res.meta.name);
    Converged(i) = logical(res.flags.converged);
    RulePass(i) = logical(res.flags.rulePass);
    DesignPass(i) = logical(res.flags.designPass);
    Feasible(i) = logical(res.flags.feasible);

    FrontSpring(i) = mean(res.inputs.sus.ks(1:2));
    RearSpring(i) = mean(res.inputs.sus.ks(3:4));
    Z_mm(i) = res.state.z * 1e3;
    Theta_deg(i) = res.state.theta_deg;
    Phi_deg(i) = res.state.phi_deg;
    Hf_mm(i) = res.aero.hf * 1e3;
    Hr_mm(i) = res.aero.hr * 1e3;
    AeroLoad_N(i) = res.aero.Fz;
    Drag_N(i) = res.aero.Drag;
    LossPct(i) = res.aero.lossPct;
    FrontShare(i) = res.aero.frontShare;
    FrontShareMigrationPct(i) = res.aero.frontShareMigrationPct;

    hStaticMin(i) = res.clearance.hStaticMin;
    hStaticMin_mm(i) = res.clearance.hStaticMin * 1e3;
    hDynamicMin(i) = res.clearance.hDynamicMin;
    hDynamicMin_mm(i) = res.clearance.hDynamicMin * 1e3;
    hDynamicMinBumpAdjusted(i) = res.clearance.hDynamicMinBumpAdjusted;
    hDynamicMinBumpAdjusted_mm(i) = res.clearance.hDynamicMinBumpAdjusted * 1e3;
    hMin(i) = res.clearance.hMin;
    hMin_mm(i) = res.clearance.hMin * 1e3;

    StaticGroundClearancePass(i) = logical(res.rules.staticGroundClearancePass);
    DynamicClearancePass(i) = logical(res.targets.dynamicClearancePass);
    DynamicClearanceBumpAdjustedPass(i) = logical(res.clearance.dynamicClearanceBumpAdjustedPass);
    AeroPlatformPass(i) = logical(res.flags.aeroPlatformPass);
    ScrapePassQuasiStatic(i) = logical(res.flags.scrapePassQuasiStatic);
    ScrapePassBumpAdjusted(i) = logical(res.flags.scrapePassBumpAdjusted);
    mapClassQuasiStatic(i) = res.flags.mapClassQuasiStatic;
    mapClassBumpAdjusted(i) = res.flags.mapClassBumpAdjusted;
    mapLabelQuasiStatic(i) = string(res.flags.mapClassQuasiStaticLabel);
    mapLabelBumpAdjusted(i) = string(res.flags.mapClassBumpAdjustedLabel);
    aeroLossPass(i) = logical(res.targets.aeroLossPass);
    frontShareMigrationPass(i) = logical(res.targets.frontShareMigrationPass);

    EffectiveJounce(i) = res.rules.minEffectiveJounce;
    EffectiveJounce_mm(i) = res.rules.minEffectiveJounce * 1e3;
    EffectiveDroop(i) = res.rules.minEffectiveDroop;
    EffectiveDroop_mm(i) = res.rules.minEffectiveDroop * 1e3;
    EffectiveTotalTravel(i) = res.rules.minEffectiveTotalTravel;
    EffectiveTotalTravel_mm(i) = res.rules.minEffectiveTotalTravel * 1e3;

    TravelViolation(i) = logical(res.flags.travelViolationAny);
    ClearanceViolation(i) = logical(res.flags.clearanceViolation);
    BumpAdjustedClearanceViolation(i) = logical(res.flags.bumpAdjustedClearanceViolation);
    ShockCompViolation(i) = logical(res.flags.shockCompViolationAny);
    ShockReboundViolation(i) = logical(res.flags.shockReboundViolationAny);

    MaxWheelJounceUsagePct(i) = res.metrics.maxWheelJounceUsagePct;
    MaxWheelDroopUsagePct(i) = res.metrics.maxWheelDroopUsagePct;
    MaxShockCompUsagePct(i) = res.metrics.maxShockCompUsagePct;
    MaxShockReboundUsagePct(i) = res.metrics.maxShockReboundUsagePct;
    MinShockCompMargin_mm(i) = res.metrics.minShockCompMargin * 1e3;
    MinShockReboundMargin_mm(i) = res.metrics.minShockReboundMargin * 1e3;

    ShockStaticPositionPct(i) = res.metrics.shockStaticPositionPct;
    ShockBiasFromMidPct(i) = res.metrics.shockBiasFromMidPct;
    BumpReserveFront(i) = res.metrics.bumpReserveFront;
    BumpReserveRear(i) = res.metrics.bumpReserveRear;

    TireMode(i) = string(res.tire.mode);
    KtCase(i) = string(res.tire.ktCaseLabel);
    KtBand(i) = format_kt_band(res.tire.ktBand);

    tireEvalFailed(i) = logical(res.flags.tireEvalFailed);
    tireOutOfRange(i) = logical(res.flags.tireOutOfRange);
    contactLostAny(i) = logical(res.flags.contactLostAny);
    FyFrontTotal(i) = res.tire.balance.FyFrontTotal;
    FyRearTotal(i) = res.tire.balance.FyRearTotal;
    FxFrontTotal(i) = res.tire.balance.FxFrontTotal;
    FxRearTotal(i) = res.tire.balance.FxRearTotal;
    frontFyShare(i) = res.tire.balance.frontFyShare;
    rearFyShare(i) = res.tire.balance.rearFyShare;
    balanceIndex(i) = res.tire.balance.balanceIndex;
    peakMarginFront(i) = res.tire.balance.peakMarginFront;
    peakMarginRear(i) = res.tire.balance.peakMarginRear;
    maxAbsMuY(i) = res.tire.coeff.maxAbsMuY;
    maxAbsMuX(i) = res.tire.coeff.maxAbsMuX;
end

% ===== 向后兼容字段 + V1.0.4 新增筛选字段 =====
staticGroundClearancePass = StaticGroundClearancePass;
dynamicClearancePass = DynamicClearancePass;
dynamicClearanceBumpAdjustedPass = DynamicClearanceBumpAdjustedPass;
aeroPlatformPass = AeroPlatformPass;
scrapePassQuasiStatic = ScrapePassQuasiStatic;
scrapePassBumpAdjusted = ScrapePassBumpAdjusted;
effectiveJounce = EffectiveJounce;
effectiveDroop = EffectiveDroop;
effectiveTotalTravel = EffectiveTotalTravel;
feasible = Feasible;

summaryTable = table(Name, Converged, RulePass, DesignPass, Feasible, ...
    FrontSpring, RearSpring, ...
    Z_mm, Theta_deg, Phi_deg, Hf_mm, Hr_mm, ...
    hStaticMin, hStaticMin_mm, hDynamicMin, hDynamicMin_mm, ...
    hDynamicMinBumpAdjusted, hDynamicMinBumpAdjusted_mm, hMin, hMin_mm, ...
    StaticGroundClearancePass, DynamicClearancePass, DynamicClearanceBumpAdjustedPass, ...
    AeroPlatformPass, ScrapePassQuasiStatic, ScrapePassBumpAdjusted, ...
    mapClassQuasiStatic, mapClassBumpAdjusted, mapLabelQuasiStatic, mapLabelBumpAdjusted, ...
    aeroLossPass, frontShareMigrationPass, ...
    EffectiveJounce, EffectiveJounce_mm, EffectiveDroop, EffectiveDroop_mm, ...
    EffectiveTotalTravel, EffectiveTotalTravel_mm, ...
    AeroLoad_N, Drag_N, LossPct, FrontShare, FrontShareMigrationPct, ...
    TravelViolation, ClearanceViolation, BumpAdjustedClearanceViolation, ...
    ShockCompViolation, ShockReboundViolation, ...
    MaxWheelJounceUsagePct, MaxWheelDroopUsagePct, MaxShockCompUsagePct, MaxShockReboundUsagePct, ...
    MinShockCompMargin_mm, MinShockReboundMargin_mm, ...
    ShockStaticPositionPct, ShockBiasFromMidPct, BumpReserveFront, BumpReserveRear, ...
    TireMode, KtCase, KtBand, ...
    tireEvalFailed, tireOutOfRange, contactLostAny, ...
    FyFrontTotal, FyRearTotal, FxFrontTotal, FxRearTotal, ...
    frontFyShare, rearFyShare, balanceIndex, peakMarginFront, peakMarginRear, ...
    maxAbsMuY, maxAbsMuX, ...
    staticGroundClearancePass, dynamicClearancePass, dynamicClearanceBumpAdjustedPass, ...
    aeroPlatformPass, scrapePassQuasiStatic, scrapePassBumpAdjusted, ...
    effectiveJounce, effectiveDroop, effectiveTotalTravel, feasible);

batchResults = struct();
batchResults.resultsList = resultsList;
batchResults.nCases = n;
batchResults.nConverged = sum(Converged);
batchResults.nFeasible = sum(Feasible);
batchResults.summaryTable = summaryTable;
end

function s = format_kt_band(ktBand)
if isempty(ktBand) || any(~isfinite(ktBand))
    s = "";
else
    s = sprintf('%.0f|%.0f|%.0f', ktBand(1), ktBand(2), ktBand(3));
end
end
