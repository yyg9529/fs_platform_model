function test_tire_op_direct_scalar_expand()
%TEST_TIRE_OP_DIRECT_SCALAR_EXPAND direct 模式标量自动扩展为四角点。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_test_tire_proxy_case();
caseDef.tire.forceModel.enable = false;
platformRes = run_case(caseDef);

caseDef = build_test_tire_proxy_case();
caseDef.tireOp.mode = 'direct';
caseDef.tireOp.alpha = 5.0;
caseDef.tireOp.kappa = 0.03;
caseDef.tireOp.gamma = -2.0;
caseDef.tireOp.pressure = 90000;
caseDef.tireOp.alphaUnit = 'deg';
caseDef.tireOp.gammaUnit = 'deg';

tireData = load_tire_table_data(caseDef);
op = normalize_tire_operating_points(caseDef, platformRes, tireData);

assert(isequal(size(op.alpha), [4, 1]), 'Expected [4x1] alpha.');
assert(max(abs(op.alpha - deg2rad(5.0))) < 1e-12, 'Expected scalar alpha expansion.');
assert(max(abs(op.kappa - 0.03)) < 1e-12, 'Expected scalar kappa expansion.');
assert(max(abs(op.gamma - deg2rad(-2.0))) < 1e-12, 'Expected scalar gamma expansion.');
assert(max(abs(op.pressure - 90000)) < 1e-12, 'Expected scalar pressure expansion.');

fprintf('[PASS] test_tire_op_direct_scalar_expand\n');
end
