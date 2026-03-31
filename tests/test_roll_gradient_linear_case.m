function test_roll_gradient_linear_case()
%TEST_ROLL_GRADIENT_LINEAR_CASE 线性侧倾解析一致性测试。
% 功能说明:
%   在无气动且线性角点刚度条件下，验证 phi ≈ Mroll / Kphi。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();

% 关闭气动
caseDef.aero.mapType = 'function_handle';
caseDef.aero.mapData = struct( ...
    'CzFun', @(hf,hr,phi,beta) 0.0, ...
    'CdFun', @(hf,hr,phi,beta) 0.0, ...
    'frontShareFun', @(hf,hr,phi,beta) 0.5, ...
    'pitchMomentFun', @(hf,hr,phi,beta) 0.0);
caseDef.aero.nominalRef = struct('VGrid', [0;1], 'FzNominal', [0;0], 'frontShareNominal', [0.5;0.5]);

caseDef.man.V = 0.0;
caseDef.man.ax = 0.0;
caseDef.man.ay = 6.0;
caseDef.man.beta = 0.0;
caseDef.solver.useAeroIter = false;

results = run_case(caseDef);

casePre = preprocess_case(caseDef);
Kphi = casePre.derived.stiff.K(3,3);
Mroll = casePre.veh.m * casePre.man.ay * (casePre.veh.hCG - casePre.derived.hRA_CG);
phiExpected = Mroll / Kphi;

absErr = abs(results.state.phi - phiExpected);
assert(absErr < 5e-5, 'Linear roll gradient check failed: phi mismatch too large.');

fprintf('[PASS] test_roll_gradient_linear_case\n');
end
