function test_tire_op_proxy_generation()
%TEST_TIRE_OP_PROXY_GENERATION proxy 模式能正确生成四角点 alpha / kappa / gamma。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_test_tire_proxy_case();
caseDef.tire.forceModel.enable = false;
platformRes = run_case(caseDef);

caseDef = build_test_tire_proxy_case();
caseDef.tireOp.mode = 'proxy';
caseDef.tireOp.alphaUnit = 'deg';
caseDef.tireOp.gammaUnit = 'deg';
caseDef.tireOp.alphaFront = 6.0;
caseDef.tireOp.alphaRear = 3.0;
caseDef.tireOp.kappaFront = -0.02;
caseDef.tireOp.kappaRear = 0.01;
caseDef.tireOp.gammaStatic = 0.0;
caseDef.tireOp.camberGainSusp = 0.0;
caseDef.tireOp.camberGainRoll = 0.0;
caseDef.tireOp.toeStatic = 0.0;

tireData = load_tire_table_data(caseDef);
op = normalize_tire_operating_points(caseDef, platformRes, tireData);

assert(max(abs(op.alpha(1:2) - deg2rad(6.0))) < 1e-12, 'Expected front alpha proxy to expand.');
assert(max(abs(op.alpha(3:4) - deg2rad(3.0))) < 1e-12, 'Expected rear alpha proxy to expand.');
assert(max(abs(op.kappa(1:2) - (-0.02))) < 1e-12, 'Expected front kappa proxy to expand.');
assert(max(abs(op.kappa(3:4) - 0.01)) < 1e-12, 'Expected rear kappa proxy to expand.');
assert(max(abs(op.gamma)) < 1e-12, 'Expected zero gamma when static/camber gains are zero.');

fprintf('[PASS] test_tire_op_proxy_generation\n');
end
