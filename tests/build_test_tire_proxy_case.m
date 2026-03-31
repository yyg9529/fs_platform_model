function caseDef = build_test_tire_proxy_case()
%BUILD_TEST_TIRE_PROXY_CASE 构建 V1.5 轮胎代理层测试基准 case。
% 功能说明:
%   1) 基于标准 2026 target case 生成统一测试入口。
%   2) 默认关闭 rules/targets gate，避免轮胎层测试被平台判据干扰。
%   3) 默认接入示例 table_struct 轮胎数据，便于插值、combined proxy 与 scan 测试。
%
% 输入:
%   无
%
% 输出:
%   caseDef - 可直接用于 run_case 的测试案例
%
% 关键物理假设:
%   1) 轮胎力代理仍然是平台收敛后的后评估层。
%   2) 示例表格来自 build_demo_tire_force_tables，仅用于 demo/test。
%
% 单位约定:
%   全部使用 SI；direct 模式输入角度显式设为 deg 便于测试可读性

caseDef = build_case_2026_target();
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;

caseDef.tire.forceModel.enable = true;
caseDef.tire.forceModel.sourceType = 'table_struct';
caseDef.tire.forceModel.data = build_demo_tire_force_tables();
caseDef.tire.forceModel.mode = 'pure_plus_combined_proxy';
caseDef.tire.forceModel.outOfRangePolicy = 'warn_clamp';
caseDef.tire.forceModel.includeAligningMoment = true;

caseDef.tireOp.mode = 'direct';
caseDef.tireOp.alpha = 0.0;
caseDef.tireOp.kappa = 0.0;
caseDef.tireOp.gamma = [-2; -2; -1; -1];
caseDef.tireOp.pressure = 83000;
caseDef.tireOp.alphaUnit = 'deg';
caseDef.tireOp.gammaUnit = 'deg';
caseDef.tireOp.kappaUnit = 'ratio';
caseDef.tireOp.pressureUnit = 'Pa';
caseDef.tireOp.scan.enable = false;
caseDef.tireOp.scan.field = '';
caseDef.tireOp.scan.values = [];
caseDef.tireOp.scan.unit = '';
caseDef.tireOp.scan.applyMode = 'all_corners';
caseDef.tireOp.scan.notes = 'test helper default';
end
