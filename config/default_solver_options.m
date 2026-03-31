function solver = default_solver_options()
%DEFAULT_SOLVER_OPTIONS V1.0.4 求解与约束检查默认参数。
% 功能说明:
%   提供 run_case 的默认 solver 配置。
%   V1.0.4 延续 V1.0.3a 主链，新增 sweep/map 工作流所需的稳定输出语义。
%
% 输入:
%   无
%
% 输出:
%   solver - 求解器参数结构体
%
% 关键物理假设:
%   1) bump/droop 附加力不进入平衡方程（仅兼容保留）
%   2) 主求解刚度由 tire.mode 控制（off/fixed/range）
%   3) converged/rulePass/designPass/feasible 分层判定
%
% 单位约定:
%   initialGuess = [z; theta; phi]，其中 z[m], theta/phi[rad]
%   tol 作用于残差范数（广义力组合）

solver = struct();
solver.tol = 1e-7;
solver.maxIter = 60;
solver.relax = 0.75;

% ===== 求解器主开关 =====
solver.useAeroIter = true;
solver.verbose = false;
solver.exportDebug = true;
solver.initialGuess = [0; 0; 0];

% ===== 约束检查开关 =====
solver.checkWheelTravel = true;
solver.checkShockStroke = true;

% strictTravelViolation 在 V1.0.4 继续接入 feasible 判定：
% true 时 travel/clearance 违规会直接使 feasible=false；
% false 时仍保留违规 flag，但不强制阻断 feasible。
solver.strictTravelViolation = true;

% ===== 气动插值失败策略 =====
% false: 允许 nearest fallback，并显式打标 interpFallbackUsed=true
% true : 线性插值失败时直接报错
solver.errorOnInterpFailure = false;

% ===== tire.mode=range 输出策略 =====
% true: run_case 顶层主结果取 nominal，同时附带 range.low/nominal/high
% false: 顶层主结果取 low（保守筛选），同时仍附带完整 range 输出
solver.rangeUseNominalAsPrimary = true;

% ===== deprecated / warning 兼容开关 =====
% useNonlinearCorner 仅兼容旧接口，已不参与 V1.0.4 主求解
solver.useNonlinearCorner = false;

% warnOnDeprecatedInput=true 时，run_case 会把 validation.warnings 真实发成 warning(...)
solver.warnOnDeprecatedInput = true;
end
