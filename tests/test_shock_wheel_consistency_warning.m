function test_shock_wheel_consistency_warning()
%TEST_SHOCK_WHEEL_CONSISTENCY_WARNING shock/wheel 输入一致性警告测试。
% 功能说明:
%   构造“shock 可用压缩极小、但 jounceMax 很大”的矛盾输入，
%   验证 consistency warning 标志被正确置位。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

% comp avail 仅 1 mm，而 jounceMax 仍为数厘米级，构造明显不一致
caseDef.sus.shockLenExtended = 0.320;
caseDef.sus.shockLenCompressed = 0.260;
caseDef.sus.shockLenStatic = 0.261;

results = run_case(caseDef);

assert(results.flags.shockWheelConsistencyWarning, ...
    'Expected shock-wheel consistency warning to be true.');
assert(min(results.debug.validation.wheelJounceFromShock) < 0.005, ...
    'Expected derived wheelJounceFromShock to be very small in this setup.');

fprintf('[PASS] test_shock_wheel_consistency_warning\n');
end
