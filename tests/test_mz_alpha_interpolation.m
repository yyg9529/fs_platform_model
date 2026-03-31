function test_mz_alpha_interpolation()
%TEST_MZ_ALPHA_INTERPOLATION Mz(alpha,Fz,gamma) 插值输出有限、连续且尺寸正确。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseA = build_test_tire_proxy_case();
caseA.tireOp.alpha = 4.0;
caseA.tireOp.kappa = 0.0;

caseB = caseA;
caseB.tireOp.alpha = 4.5;

resA = run_case(caseA);
resB = run_case(caseB);

assert(isequal(size(resA.tire.forces.Mz), [4, 1]), 'Expected Mz size [4x1].');
assert(all(isfinite(resA.tire.forces.Mz)), 'Expected finite Mz.');
assert(all(isfinite(resB.tire.forces.Mz)), 'Expected finite Mz for nearby alpha.');
assert(max(abs(resB.tire.forces.Mz - resA.tire.forces.Mz)) > 1e-5, 'Expected Mz to vary with alpha.');
assert(max(abs(resB.tire.forces.Mz - resA.tire.forces.Mz)) < 500, 'Expected Mz variation to remain smooth.');

fprintf('[PASS] test_mz_alpha_interpolation\n');
end
