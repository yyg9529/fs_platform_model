function test_aero_platform_pass_definition()
%TEST_AERO_PLATFORM_PASS_DEFINITION 验证 aeroPlatformPass 的正式定义。
% 功能说明:
%   1) aeroPlatformPass 只由 aeroLossPass 与 frontShareMigrationPass 构成。
%   2) clearance 失败不应自动把 aeroPlatformPass 拉成 false。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = true;
caseDef.targets.maxAeroLossPct = 1e6;
caseDef.targets.maxFrontShareMigrationPct = 1e6;
caseDef.targets.minDynamicClearance = 0.050; % 人为抬高，迫使 dynamicClearancePass=false

res = run_case(caseDef);

assert(~res.targets.dynamicClearancePass, 'Expected dynamic clearance target to fail.');
assert(res.targets.aeroLossPass && res.targets.frontShareMigrationPass, ...
    'Expected aero sub-targets to pass.');
assert(res.flags.aeroPlatformPass, ...
    'Expected aeroPlatformPass to remain true even when dynamic clearance target fails.');
assert(res.flags.aeroPlatformPass == (res.targets.aeroLossPass && res.targets.frontShareMigrationPass), ...
    'Expected aeroPlatformPass to equal aeroLossPass && frontShareMigrationPass.');

fprintf('[PASS] test_aero_platform_pass_definition\n');
end
