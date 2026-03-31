function test_shock_comp_violation()
%TEST_SHOCK_COMP_VIOLATION shock 压缩端越界判据测试。
% 功能说明:
%   构造大下压力工况并设置极小压缩余量，验证压缩端违规 flag。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();

% 设置极小压缩可用量（comp avail = 0.2 mm）
caseDef.sus.shockLenExtended = 0.320;
caseDef.sus.shockLenCompressed = 0.260;
caseDef.sus.shockLenStatic = 0.2602;

% 构造大下压力以产生明显压缩
caseDef.aero.mapType = 'function_handle';
caseDef.aero.mapData = struct( ...
    'CzFun', @(hf,hr,phi,beta) 10.0, ...
    'CdFun', @(hf,hr,phi,beta) 0.8, ...
    'frontShareFun', @(hf,hr,phi,beta) 0.5, ...
    'pitchMomentFun', @(hf,hr,phi,beta) 0.0);
caseDef.aero.nominalRef = struct('VGrid', [0;1], 'FzNominal', [0;0], 'frontShareNominal', [0.5;0.5]);

caseDef.man.V = 35.0;
caseDef.man.ax = 0.0;
caseDef.man.ay = 0.0;
caseDef.man.beta = 0.0;

results = run_case(caseDef);

assert(results.flags.converged, 'Case should converge numerically.');
assert(results.flags.shockCompViolationAny, 'Expected shock compression violation under high downforce.');
assert(results.flags.travelViolationAny, 'Expected travelViolationAny=true when shock comp violates.');

fprintf('[PASS] test_shock_comp_violation\n');
end
