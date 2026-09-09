function results = demo_tire_table_brake_in_turn()
%DEMO_TIRE_TABLE_BRAKE_IN_TURN V1.5 代表性 brake-in-turn 轮胎代理层示例。
% 功能说明:
%   1) 基于平台 operating point 评估代表性 brake-in-turn 工况。
%   2) 当只有 pure tables 可用时，使用 combined proxy 近似 combined-slip 能力。
%   3) 通过前轴 brake kappa scan 输出 balance/utilization 变化趋势。
%
% 输入:
%   无
%
% 输出:
%   results - 含 V1.5 results.tire.scan 的完整结果结构
%
% 关键物理假设:
%   1) combined proxy 是概念设计阶段近似，不等价于完整 Magic Formula。
%   2) scan 固定同一个平台姿态/Fz，仅改变前轴轮胎纵滑 operating point。
%
% 单位约定:
%   kappa 直接以 ratio 输入与显示；其余内部计算保持 SI

thisFile = mfilename('fullpath');
mainDir = fileparts(thisFile);
rootDir = fileparts(mainDir);
addpath(genpath(rootDir));

caseDef = build_demo_tire_proxy_case();
caseDef.meta.name = 'Demo_V15_Brake_In_Turn';
caseDef.tireOp.mode = 'proxy';
caseDef.tireOp.alphaUnit = 'deg';
caseDef.tireOp.gammaUnit = 'deg';
caseDef.tireOp.alphaFront = 7.0;
caseDef.tireOp.alphaRear = 4.0;
caseDef.tireOp.kappaFront = -0.05;
caseDef.tireOp.kappaRear = 0.0;
caseDef.tireOp.gammaStatic = [-2.5; -2.5; -1.5; -1.5];
caseDef.tireOp.camberGainSusp = [0.22; 0.22; 0.14; 0.14];
caseDef.tireOp.camberGainRoll = [-0.85; 0.85; -0.45; 0.45];
caseDef.tireOp.scan.enable = true;
caseDef.tireOp.scan.field = 'kappa';
caseDef.tireOp.scan.values = (-0.12:0.01:0.02).';
caseDef.tireOp.scan.unit = 'ratio';
caseDef.tireOp.scan.applyMode = 'front_axle';
caseDef.tireOp.scan.notes = 'Representative brake-in-turn front axle brake sweep';

results = run_case(caseDef);

fprintf('=== Demo Tire Brake-in-Turn: %s ===\n', results.meta.name);
fprintf('Tire force model enabled: %d\n', results.flags.tireForceModelEnabled);
fprintf('Tire eval failed: %d\n', results.flags.tireEvalFailed);
fprintf('FrontFyShare: %.3f\n', results.tire.balance.frontFyShare);
fprintf('BalanceIndex: %.3f\n', results.tire.balance.balanceIndex);
fprintf('PeakMargin Front/Rear: %.3f / %.3f\n', ...
    results.tire.balance.peakMarginFront, results.tire.balance.peakMarginRear);

plot_tire_table_scan(results);
end
