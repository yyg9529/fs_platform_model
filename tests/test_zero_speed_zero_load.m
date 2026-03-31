function test_zero_speed_zero_load()
%TEST_ZERO_SPEED_ZERO_LOAD 零速零纵横向载荷工况回归测试。
% 功能说明:
%   验证 V=0、ax=0、ay=0 时三自由度平衡解应为零。
%   本测试关闭 rules/targets 强制，仅检查基础求解链路。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.man.V = 0.0;
caseDef.man.ax = 0.0;
caseDef.man.ay = 0.0;
caseDef.man.beta = 0.0;
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

results = run_case(caseDef);

tol = 1e-10;
assert(abs(results.state.z) < tol, 'Expected z=0 at zero load condition.');
assert(abs(results.state.theta) < tol, 'Expected theta=0 at zero load condition.');
assert(abs(results.state.phi) < tol, 'Expected phi=0 at zero load condition.');
assert(results.flags.converged, 'Zero-load case should converge.');
assert(results.flags.feasible, 'Zero-load case should be feasible when rules/targets are not enforced.');

fprintf('[PASS] test_zero_speed_zero_load\n');
end
