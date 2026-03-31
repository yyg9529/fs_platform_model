function test_combined_proxy_brake_in_turn()
%TEST_COMBINED_PROXY_BRAKE_IN_TURN 只有 pure tables 时，combined proxy 仍可输出合理结果。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_test_tire_proxy_case();
caseDef.tire.forceModel.mode = 'pure_plus_combined_proxy';
caseDef.tireOp.mode = 'proxy';
caseDef.tireOp.alphaUnit = 'deg';
caseDef.tireOp.gammaUnit = 'deg';
caseDef.tireOp.alphaFront = 7.0;
caseDef.tireOp.alphaRear = 4.0;
caseDef.tireOp.kappaFront = -0.10;
caseDef.tireOp.kappaRear = 0.0;
caseDef.tireOp.gammaStatic = [-2.5; -2.5; -1.5; -1.5];

res = run_case(caseDef);

assert(res.tire.balance.usedCombinedProxyAny, 'Expected combined proxy to be used when no CombinedTable exists.');
assert(all(isfinite(res.tire.forces.Fx(1:2))), 'Expected finite front axle Fx in brake-in-turn case.');
assert(all(isfinite(res.tire.forces.Fy(1:2))), 'Expected finite front axle Fy in brake-in-turn case.');
assert(isfinite(res.tire.balance.balanceIndex), 'Expected finite balanceIndex.');
assert(isfinite(res.tire.balance.peakMarginFront), 'Expected finite peak margin from combined proxy.');

fprintf('[PASS] test_combined_proxy_brake_in_turn\n');
end
