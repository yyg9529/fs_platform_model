function test_fy_alpha_interpolation()
%TEST_FY_ALPHA_INTERPOLATION Fy(alpha,Fz,gamma) 插值输出有限、连续且尺寸正确。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseA = build_test_tire_proxy_case();
caseA.tireOp.alpha = 5.0;
caseA.tireOp.kappa = 0.0;

caseB = caseA;
caseB.tireOp.alpha = 5.5;

resA = run_case(caseA);
resB = run_case(caseB);

assert(isequal(size(resA.tire.forces.Fy), [4, 1]), 'Expected Fy size [4x1].');
assert(all(isfinite(resA.tire.forces.Fy)), 'Expected finite Fy.');
assert(all(isfinite(resB.tire.forces.Fy)), 'Expected finite Fy for nearby alpha.');
assert(max(abs(resB.tire.forces.Fy - resA.tire.forces.Fy)) > 1e-3, 'Expected Fy to vary with alpha.');
assert(max(abs(resB.tire.forces.Fy - resA.tire.forces.Fy)) < 5e3, 'Expected Fy variation to remain smooth.');

fprintf('[PASS] test_fy_alpha_interpolation\n');
end
