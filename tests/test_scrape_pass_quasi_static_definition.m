function test_scrape_pass_quasi_static_definition()
%TEST_SCRAPE_PASS_QUASI_STATIC_DEFINITION 验证 scrapePassQuasiStatic 的正式定义。
% 功能说明:
%   1) scrapePassQuasiStatic 只由 staticGroundClearancePass、dynamicClearancePass、clearanceViolation 构成。
%   2) aero 相关目标失败不应直接影响 scrapePassQuasiStatic。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;
caseDef.rules.enforceRules = false;
caseDef.rules.minStaticGroundClearance = 0.0;
caseDef.targets.enforceTargets = true;
caseDef.targets.minDynamicClearance = 0.0;
caseDef.targets.maxAeroLossPct = 0.0; % 强制 aeroLossPass 失败
caseDef.targets.maxFrontShareMigrationPct = 0.0; % 强制 frontShareMigrationPass 失败

res = run_case(caseDef);
expected = res.rules.staticGroundClearancePass && res.targets.dynamicClearancePass && ~res.flags.clearanceViolation;

assert(res.flags.scrapePassQuasiStatic == expected, ...
    'Expected scrapePassQuasiStatic to follow its formal definition.');
assert(~res.flags.aeroPlatformPass, 'Expected aeroPlatformPass=false in this test.');
assert(res.flags.scrapePassQuasiStatic, ...
    'Expected scrapePassQuasiStatic to stay true even when aero platform fails.');

fprintf('[PASS] test_scrape_pass_quasi_static_definition\n');
end
