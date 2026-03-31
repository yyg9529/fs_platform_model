function test_feasible_flag()
%TEST_FEASIBLE_FLAG converged 与 feasible 分离测试。
% 功能说明:
%   构造 travel 违规工况，验证：
%   converged = true 但 feasible = false。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;
caseDef.solver.strictTravelViolation = true;

% 构造压缩端越界但可收敛的工况
caseDef.sus.shockLenExtended = 0.320;
caseDef.sus.shockLenCompressed = 0.260;
caseDef.sus.shockLenStatic = 0.2602;
caseDef.aero.mapType = 'function_handle';
caseDef.aero.mapData = struct( ...
    'CzFun', @(hf,hr,phi,beta) 10.0, ...
    'CdFun', @(hf,hr,phi,beta) 0.8, ...
    'frontShareFun', @(hf,hr,phi,beta) 0.5, ...
    'pitchMomentFun', @(hf,hr,phi,beta) 0.0);
caseDef.aero.nominalRef = struct('VGrid', [0;1], 'FzNominal', [0;0], 'frontShareNominal', [0.5;0.5]);
caseDef.man.V = 35.0;
caseDef.man.ax = 0;
caseDef.man.ay = 0;

results = run_case(caseDef);

assert(results.flags.converged, 'Expected converged=true for numerically solvable case.');
assert(~results.flags.feasible, 'Expected feasible=false when strict travel constraints are violated.');
assert(results.flags.shockCompViolationAny || results.flags.travelViolationAny, ...
    'Expected travel-related violation to make feasible=false.');

fprintf('[PASS] test_feasible_flag\n');
end
