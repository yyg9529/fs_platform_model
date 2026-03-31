function test_static_symmetry()
%TEST_STATIC_SYMMETRY 左右对称静态工况测试。
% 功能说明:
%   验证左右对称刚度和对称工况下，左右角点增量力应相等且 phi=0。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2025_baseline();
caseDef.man.ay = 0.0;
caseDef.man.ax = 0.0;
caseDef.man.beta = 0.0;

results = run_case(caseDef);

tol = 1e-8;
FL = results.corners.Ftotal(1);
FR = results.corners.Ftotal(2);
RL = results.corners.Ftotal(3);
RR = results.corners.Ftotal(4);

assert(abs(FL - FR) < tol, 'Expected FL=FR under symmetric condition.');
assert(abs(RL - RR) < tol, 'Expected RL=RR under symmetric condition.');
assert(abs(results.state.phi) < tol, 'Expected phi=0 under symmetric condition.');
assert(results.flags.converged, 'Symmetry case should converge.');

fprintf('[PASS] test_static_symmetry\n');
end
