function results = postprocess_tire_results(results, caseDef, tireTableData, tireOpNorm, tireEval)
%POSTPROCESS_TIRE_RESULTS 将 V1.5 轮胎代理结果整理进正式 results.tire 结构。
% 功能说明:
%   1) 在不破坏 V1.0.4 既有 tire.mode/kt 语义的前提下，新增 forceModel 结果层。
%   2) 输出四角点 Fx/Fy/Mz、muX/muY、前后轴 balance/utilization/peak margin。
%   3) 保留 scan 数据，便于后续批处理、绘图与方案筛选。
%
% 输入:
%   results       - postprocess_results 输出的基础结果
%   caseDef       - 预处理后的输入结构
%   tireTableData - 统一轮胎表结构
%   tireOpNorm    - 归一化四角点 operating point
%   tireEval      - evaluate_tire_table_model 输出
%
% 输出:
%   results - 补齐 results.tire / results.flags / results.metrics 的结构体
%
% 关键物理假设:
%   1) 轮胎后评估层与平台主求解器分离，不反向改写 q=[z;theta;phi] 主链。
%   2) Fz 必须来自平台收敛结果，不接受额外独立手填。
%   3) balanceIndex 采用“前轴峰值利用率 - 后轴峰值利用率”的代理定义。
%
% 单位约定:
%   Fz/Fx/Fy [N]，Mz [N*m]，alpha/gamma [rad]，[FL FR RL RR] 固定顺序

Fz = tireEval.Fz(:);
Fx = tireEval.Fx(:);
Fy = tireEval.Fy(:);
Mz = tireEval.Mz(:);

muX = Fx ./ max(Fz, eps);
muY = Fy ./ max(Fz, eps);

FyFrontTotal = sum(Fy(1:2), 'omitnan');
FyRearTotal = sum(Fy(3:4), 'omitnan');
FxFrontTotal = sum(Fx(1:2), 'omitnan');
FxRearTotal = sum(Fx(3:4), 'omitnan');

frontFyShare = abs(FyFrontTotal) / max(abs(FyFrontTotal) + abs(FyRearTotal), eps);
rearFyShare = abs(FyRearTotal) / max(abs(FyFrontTotal) + abs(FyRearTotal), eps);

frontUtilization = max(tireEval.utilizationDemand(1:2), [], 'omitnan');
rearUtilization = max(tireEval.utilizationDemand(3:4), [], 'omitnan');
peakMarginFront = min(tireEval.peakMargin(1:2), [], 'omitnan');
peakMarginRear = min(tireEval.peakMargin(3:4), [], 'omitnan');
balanceIndex = frontUtilization - rearUtilization;

results.tire.forceModel = struct();
results.tire.forceModel.enable = true;
results.tire.forceModel.sourceType = lower(strtrim(char(string(caseDef.tire.forceModel.sourceType))));
results.tire.forceModel.mode = lower(strtrim(char(string(caseDef.tire.forceModel.mode))));
results.tire.forceModel.outOfRangePolicy = lower(strtrim(char(string(caseDef.tire.forceModel.outOfRangePolicy))));
results.tire.forceModel.includeAligningMoment = logical(caseDef.tire.forceModel.includeAligningMoment);
results.tire.forceModel.sourceFile = tireTableData.sourceFile;
results.tire.forceModel.dataSummary = tireTableData.summary;

results.tire.inputs = struct();
results.tire.inputs.cornerOrder = {'FL'; 'FR'; 'RL'; 'RR'};
results.tire.inputs.alpha = tireOpNorm.alpha(:);
results.tire.inputs.alphaDeg = tireOpNorm.alphaDeg(:);
results.tire.inputs.kappa = tireOpNorm.kappa(:);
results.tire.inputs.gamma = tireOpNorm.gamma(:);
results.tire.inputs.gammaDeg = tireOpNorm.gammaDeg(:);
results.tire.inputs.pressure = tireOpNorm.pressure(:);
results.tire.inputs.Fz = Fz;
results.tire.inputs.sourceType = results.tire.forceModel.sourceType;
results.tire.inputs.mode = results.tire.forceModel.mode;
results.tire.inputs.outOfRangePolicy = results.tire.forceModel.outOfRangePolicy;
results.tire.inputs.dataSummary = tireTableData.summary.label;
results.tire.inputs.meta = tireTableData.meta;

results.tire.forces = struct();
results.tire.forces.Fx = Fx;
results.tire.forces.Fy = Fy;
results.tire.forces.Mz = Mz;
results.tire.forces.FxRequested = tireEval.FxRequested(:);
results.tire.forces.FyRequested = tireEval.FyRequested(:);
results.tire.forces.FxCap = tireEval.FxCap(:);
results.tire.forces.FyCap = tireEval.FyCap(:);

results.tire.coeff = struct();
results.tire.coeff.muX = muX;
results.tire.coeff.muY = muY;
results.tire.coeff.maxAbsMuX = max(abs(muX), [], 'omitnan');
results.tire.coeff.maxAbsMuY = max(abs(muY), [], 'omitnan');

results.tire.utilization = struct();
results.tire.utilization.requested = tireEval.utilizationDemand(:);
results.tire.utilization.clipped = tireEval.utilization(:);
results.tire.utilization.constraintValue = tireEval.constraintValue(:);

results.tire.balance = struct();
results.tire.balance.FyFrontTotal = FyFrontTotal;
results.tire.balance.FyRearTotal = FyRearTotal;
results.tire.balance.FxFrontTotal = FxFrontTotal;
results.tire.balance.FxRearTotal = FxRearTotal;
results.tire.balance.frontFyShare = frontFyShare;
results.tire.balance.rearFyShare = rearFyShare;
results.tire.balance.frontUtilization = frontUtilization;
results.tire.balance.rearUtilization = rearUtilization;
results.tire.balance.balanceIndex = balanceIndex;
results.tire.balance.peakMarginFront = peakMarginFront;
results.tire.balance.peakMarginRear = peakMarginRear;
results.tire.balance.conditionType = tireEval.conditionType;
results.tire.balance.usedCombinedProxyAny = any(tireEval.usedCombinedProxy);
results.tire.balance.usedCombinedTableAny = any(tireEval.usedCombinedTable);

results.tire.validity = struct();
results.tire.validity.validFz = tireEval.validity.validFz(:);
results.tire.validity.validAlpha = tireEval.validity.validAlpha(:);
results.tire.validity.validKappa = tireEval.validity.validKappa(:);
results.tire.validity.validGamma = tireEval.validity.validGamma(:);
results.tire.validity.outOfRange = tireEval.validity.outOfRange(:);
results.tire.validity.outOfRangeAny = logical(tireEval.validity.outOfRangeAny);
results.tire.validity.contactLost = tireEval.validity.contactLost(:);
results.tire.validity.contactLostAny = logical(tireEval.validity.contactLostAny);
results.tire.validity.evalFailed = false;
results.tire.validity.evaluationSkipped = false;
results.tire.validity.wasClipped = tireEval.wasClipped(:);

results.tire.scan = tireEval.scan;

results.flags.tireForceModelEnabled = true;
results.flags.tireEvalFailed = false;
results.flags.tireEvaluationSkipped = false;
results.flags.tireOutOfRange = results.tire.validity.outOfRangeAny;
results.flags.contactLostAny = results.tire.validity.contactLostAny;
if results.tire.validity.outOfRangeAny || results.tire.validity.contactLostAny
    if results.tire.validity.contactLostAny
        reason = 'Tire evaluation invalid because one or more corners lost contact.';
    else
        reason = 'Tire evaluation invalid because an operating point was outside the source domain.';
    end
    results = invalidate_decision_state(results, reason);
end

results.metrics.balanceIndex = balanceIndex;
results.metrics.peakMarginFront = peakMarginFront;
results.metrics.peakMarginRear = peakMarginRear;
results.metrics.maxAbsMuX = results.tire.coeff.maxAbsMuX;
results.metrics.maxAbsMuY = results.tire.coeff.maxAbsMuY;
end
