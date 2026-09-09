function results = demo_tire_table_pure_lateral()
%DEMO_TIRE_TABLE_PURE_LATERAL V1.5 纯侧偏轮胎代理层示例。
% 功能说明:
%   1) 基于平台收敛结果评估 pure lateral 轮胎 operating point。
%   2) 使用示例 table_struct 轮胎数据执行 alpha scan。
%   3) 输出 results，并保留 results.tire.scan 供后续分析/批处理使用。
%
% 输入:
%   无
%
% 输出:
%   results - 含 V1.5 results.tire.* 的完整结果结构
%
% 关键物理假设:
%   1) 轮胎层是平台后的后评估层，不回写主求解器。
%   2) alpha scan 固定同一个平台 operating point 的 Fz，只扫描轮胎工作点。
%
% 单位约定:
%   scan 以 deg 显示 alpha；内部计算仍为 SI

thisFile = mfilename('fullpath');
mainDir = fileparts(thisFile);
rootDir = fileparts(mainDir);
addpath(genpath(rootDir));

caseDef = build_demo_tire_proxy_case();
caseDef.meta.name = 'Demo_V15_Pure_Lateral';
caseDef.tireOp.mode = 'direct';
caseDef.tireOp.alpha = 0.0;
caseDef.tireOp.kappa = 0.0;
caseDef.tireOp.gamma = [-2; -2; -1; -1];
caseDef.tireOp.alphaUnit = 'deg';
caseDef.tireOp.gammaUnit = 'deg';
caseDef.tireOp.scan.enable = true;
caseDef.tireOp.scan.field = 'alpha';
caseDef.tireOp.scan.values = (-12:1:12).';
caseDef.tireOp.scan.unit = 'deg';
caseDef.tireOp.scan.applyMode = 'all_corners';
caseDef.tireOp.scan.notes = 'Pure lateral alpha scan at fixed platform operating point';

results = run_case(caseDef);

fprintf('=== Demo Tire Pure Lateral: %s ===\n', results.meta.name);
fprintf('Tire force model enabled: %d\n', results.flags.tireForceModelEnabled);
fprintf('Tire eval failed: %d\n', results.flags.tireEvalFailed);
fprintf('Max |muY|: %.3f\n', results.tire.coeff.maxAbsMuY);
fprintf('BalanceIndex: %.3f\n', results.tire.balance.balanceIndex);
fprintf('Scan points: %d\n', numel(results.tire.scan.valuesRaw));

plot_tire_table_scan(results);
end
