function test_fx_kappa_interpolation()
%TEST_FX_KAPPA_INTERPOLATION Fx(kappa,Fz,gamma) 插值输出有限、连续且尺寸正确。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseA = build_test_tire_proxy_case();
caseA.tireOp.alpha = 0.0;
caseA.tireOp.kappa = 0.04;

caseB = caseA;
caseB.tireOp.kappa = 0.045;

resA = run_case(caseA);
resB = run_case(caseB);

assert(isequal(size(resA.tire.forces.Fx), [4, 1]), 'Expected Fx size [4x1].');
assert(all(isfinite(resA.tire.forces.Fx)), 'Expected finite Fx.');
assert(all(isfinite(resB.tire.forces.Fx)), 'Expected finite Fx for nearby kappa.');
assert(max(abs(resB.tire.forces.Fx - resA.tire.forces.Fx)) > 1e-3, 'Expected Fx to vary with kappa.');
assert(max(abs(resB.tire.forces.Fx - resA.tire.forces.Fx)) < 5e3, 'Expected Fx variation to remain smooth.');

fprintf('[PASS] test_fx_kappa_interpolation\n');
end
