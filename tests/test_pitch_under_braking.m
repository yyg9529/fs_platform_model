function test_pitch_under_braking()
%TEST_PITCH_UNDER_BRAKING 制动俯仰趋势测试。
% 功能说明:
%   无气动条件下验证：
%   1) 制动时 theta > 0
%   2) antiDiveF 增大时 theta 下降

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

baseCase = build_case_2026_target();
baseCase.aero.mapType = 'function_handle';
baseCase.aero.mapData = struct( ...
    'CzFun', @(hf,hr,phi,beta) 0.0, ...
    'CdFun', @(hf,hr,phi,beta) 0.0, ...
    'frontShareFun', @(hf,hr,phi,beta) 0.5, ...
    'pitchMomentFun', @(hf,hr,phi,beta) 0.0);
baseCase.aero.nominalRef = struct('VGrid', [0;1], 'FzNominal', [0;0], 'frontShareNominal', [0.5;0.5]);
baseCase.man.V = 0.0;
baseCase.man.ax = -6.0;
baseCase.man.ay = 0.0;
baseCase.man.beta = 0.0;
baseCase.solver.useAeroIter = false;

caseLowAnti = baseCase;
caseLowAnti.longi.antiDiveF = 0.10;

caseHighAnti = baseCase;
caseHighAnti.longi.antiDiveF = 0.65;

resLow = run_case(caseLowAnti);
resHigh = run_case(caseHighAnti);

assert(resLow.state.theta > 0, 'Expected theta > 0 under braking.');
assert(resHigh.state.theta > 0, 'Expected theta > 0 under braking (high anti-dive).');
assert(resHigh.state.theta < resLow.state.theta, ...
    'Expected higher antiDiveF to reduce braking pitch angle.');

fprintf('[PASS] test_pitch_under_braking\n');
end
