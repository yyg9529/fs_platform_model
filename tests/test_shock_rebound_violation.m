function test_shock_rebound_violation()
%TEST_SHOCK_REBOUND_VIOLATION shock 回弹端越界判据测试。
% 功能说明:
%   构造左转侧倾工况并设置极小回弹余量，验证回弹端违规 flag。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();

% 设置极小回弹可用量（rebound avail = 0.2 mm）
caseDef.sus.shockLenExtended = 0.320;
caseDef.sus.shockLenCompressed = 0.260;
caseDef.sus.shockLenStatic = 0.3198;

caseDef.man.V = 0.0;
caseDef.man.ax = 0.0;
caseDef.man.ay = 9.0;
caseDef.man.beta = 0.0;

% 关闭气动，聚焦侧倾驱动
caseDef.aero.mapType = 'function_handle';
caseDef.aero.mapData = struct( ...
    'CzFun', @(hf,hr,phi,beta) 0.0, ...
    'CdFun', @(hf,hr,phi,beta) 0.0, ...
    'frontShareFun', @(hf,hr,phi,beta) 0.5, ...
    'pitchMomentFun', @(hf,hr,phi,beta) 0.0);
caseDef.aero.nominalRef = struct('VGrid', [0;1], 'FzNominal', [0;0], 'frontShareNominal', [0.5;0.5]);

results = run_case(caseDef);

assert(results.flags.converged, 'Case should converge numerically.');
assert(results.flags.shockReboundViolationAny, 'Expected shock rebound violation under large roll droop side.');
assert(results.flags.travelViolationAny, 'Expected travelViolationAny=true when shock rebound violates.');

fprintf('[PASS] test_shock_rebound_violation\n');
end
