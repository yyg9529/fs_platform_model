function sweepOut = demo_spring_sweep_map()
%DEMO_SPRING_SWEEP_MAP V1.0.4 前后弹簧 sweep 四色筛选图示例。
% 功能说明:
%   1) 基于 2026 target case 执行前后弹簧二维扫参。
%   2) 同时生成 quasi-static 与 bump-adjusted 两张筛选图。
%   3) 输出 sweepOut，便于后续继续分析或导出。
%
% 输入:
%   无
%
% 输出:
%   sweepOut - run_spring_sweep 输出结构体
%
% 关键物理假设:
%   1) 本 demo 仍基于三自由度准静态平台模型。
%   2) bump-adjusted 图只代表保守鲁棒性筛选，不是完整瞬态 bump 模型。
%
% 单位约定:
%   内部扫参使用 N/m；绘图示例显示为 lbf/in。

thisFile = mfilename('fullpath');
mainDir = fileparts(thisFile);
rootDir = fileparts(mainDir);
addpath(genpath(rootDir));

baseCase = build_case_2026_target();
baseCase.tire.mode = 'fixed';
baseCase.tire.ktFront = 220000;
baseCase.tire.ktRear = 240000;
baseCase.bumpAdjust.enable = true;
baseCase.bumpAdjust.reserveFront = 0.004;
baseCase.bumpAdjust.reserveRear = 0.003;
baseCase.bumpAdjust.notes = 'Demo-only conservative bump reserve for robustness screening';

sweepDef = struct();
sweepDef.frontSpringSweep = (33:4:49) * 1000;
sweepDef.rearSpringSweep = (37:4:53) * 1000;
sweepDef.displayUnit = 'lbf/in';
sweepDef.tag = 'demo_v104_spring_sweep';
sweepDef.candidateRegion = struct('frontMin', 37000, 'frontMax', 45000, 'rearMin', 41000, 'rearMax', 51000);

sweepOut = run_spring_sweep(baseCase, sweepDef);

fprintf('=== Demo Spring Sweep: %s ===\n', baseCase.meta.name);
fprintf('Grid size: %d rear x %d front\n', numel(sweepOut.rearSpringValues), numel(sweepOut.frontSpringValues));
fprintf('Quasi-static both-pass count: %d\n', nnz(sweepOut.classGridQuasiStatic(:) == 3));
fprintf('Bump-adjusted both-pass count: %d\n', nnz(sweepOut.classGridBumpAdjusted(:) == 3));

plot_spring_sweep_map(sweepOut, 'quasi_static');
plot_spring_sweep_map(sweepOut, 'bump_adjusted');
end
