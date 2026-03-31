function test_bump_adjust_input_expansion()
%TEST_BUMP_ADJUST_INPUT_EXPANSION 验证 bumpAdjust 单侧输入可自动扩展到前后同值。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;
caseDef.bumpAdjust.enable = true;
caseDef.bumpAdjust.reserveFront = 0.0035;
caseDef.bumpAdjust.reserveRear = [];

res = run_case(caseDef);

assert(abs(res.metrics.bumpReserveFront - 0.0035) < 1e-12, 'Expected reserveFront to remain 0.0035 m.');
assert(abs(res.metrics.bumpReserveRear - 0.0035) < 1e-12, 'Expected empty reserveRear to expand from reserveFront.');

fprintf('[PASS] test_bump_adjust_input_expansion\n');
end
