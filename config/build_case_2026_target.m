function caseDef = build_case_2026_target()
%BUILD_CASE_2026_TARGET 构建 V1.5 的 2026 目标案例。
% 功能说明:
%   在 2025 baseline 基础上微调参数，给出可直接运行 demo 和测试的标准 target case。
%   本文件延续“标准 case 显式化”原则：
%   1) 当前正式轮胎输入统一使用 tire.*；
%   2) 不再让标准 case 正式使用 sus.kt；
%   3) 关键活跃字段在 target case 中显式回写，避免依赖 autofill warning。
%
% 输入:
%   无
%
% 输出:
%   caseDef - 标准输入结构体
%
% 关键物理假设:
%   V1.5 中 bump/droop 仍停用；轮胎柔度由 tire.mode 控制，轮胎力代理由 forceModel/tireOp 后评估。
%
% 单位约定:
%   SI（m, kg, N, rad, m/s, m/s^2）

caseDef = build_case_2025_baseline();

caseDef.meta.name = 'FS_Target_2026';
caseDef.meta.version = 'V1.5';
caseDef.meta.description = '2026 target setup for V1.5 suspension-aero-tire proxy platform simulation';
caseDef.meta.notes = 'V1.5 target: spring sweep screening + bump-adjusted scrape robustness + tire balance proxy';

% 2026 目标底盘
caseDef.veh.wf_static = 0.455;
caseDef.veh.hCG = 0.265;
caseDef.veh.lf = (1 - caseDef.veh.wf_static) * caseDef.veh.L;
caseDef.veh.lr = caseDef.veh.wf_static * caseDef.veh.L;

% 2026 目标悬架
caseDef.sus.ks = [41000; 41000; 45000; 45000];
caseDef.sus.mr = [0.92; 0.92; 0.94; 0.94];
caseDef.sus.kw = [];
caseDef.sus.kArbF = 2900;
caseDef.sus.kArbR = 2500;
caseDef.sus.shockLenExtended = [0.314; 0.314; 0.330; 0.330];
caseDef.sus.shockLenCompressed = [0.249; 0.249; 0.263; 0.263];
caseDef.sus.shockLenStatic = [0.287; 0.287; 0.301; 0.301];

% 2026 轮胎柔度输入正式统一到 tire.*。
% 默认仍使用 off，保持与早期悬架侧趋势分析的对比连续性；
% 若需要对地平台结果，切换到 fixed 或 range。
caseDef.tire.mode = 'off';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;
caseDef.tire.ktFrontRange = [190000, 220000, 250000];
caseDef.tire.ktRearRange = [210000, 240000, 270000];
caseDef.tire.notes = 'Switch to fixed/range when ground-referenced stiffness coupling is required';
caseDef.tire.forceModel.enable = false;
caseDef.tire.forceModel.sourceType = 'table_struct';
caseDef.tire.forceModel.mode = 'pure_plus_combined_proxy';
caseDef.tire.forceModel.outOfRangePolicy = 'warn_clamp';

% 2026 目标 operating point 代理：
% 这些输入只服务于 V1.5 轮胎后评估层，不回写平台主平衡方程。
caseDef.tireOp.mode = 'proxy';
caseDef.tireOp.alphaFront = 0.060;
caseDef.tireOp.alphaRear = 0.035;
caseDef.tireOp.kappaFront = -0.030;
caseDef.tireOp.kappaRear = 0.000;
caseDef.tireOp.gammaStatic = [-0.040; -0.040; -0.022; -0.022];
caseDef.tireOp.camberGainSusp = [0.22; 0.22; 0.14; 0.14];
caseDef.tireOp.camberGainRoll = [-0.90; 0.90; -0.50; 0.50];
caseDef.tireOp.toeStatic = [0.002; -0.002; 0.001; -0.001];
caseDef.tireOp.pressure = 83000;

% bump-adjusted robustness 默认关闭，不影响现有单点结果
caseDef.bumpAdjust.enable = false;
caseDef.bumpAdjust.reserveFront = 0.0;
caseDef.bumpAdjust.reserveRear = 0.0;
caseDef.bumpAdjust.notes = 'Enable in sweep studies to apply conservative bump-adjusted scrape screening';

% 纵向抗俯仰参数
caseDef.longi.antiDiveF = 0.38;
caseDef.longi.antiLiftR = 0.20;
caseDef.longi.antiSquatR = 0.42;

% 工程目标可按 2026 项目窗口收紧
caseDef.targets.maxPitchDeg = 2.8;
caseDef.targets.maxRollDeg = 3.8;
caseDef.targets.maxAeroLossPct = 25.0;
caseDef.targets.maxFrontShareMigrationPct = 7.0;

% 参考工况
caseDef.man.V = 24.0;
caseDef.man.ax = -3.0;
caseDef.man.ay = 10.0;
caseDef.man.mode = 'combined';
caseDef.man.description = '2026 target combined braking and cornering';
caseDef.man.tag = '2026_target_demo';
end
