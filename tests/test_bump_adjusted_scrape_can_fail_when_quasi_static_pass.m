function test_bump_adjusted_scrape_can_fail_when_quasi_static_pass()
%TEST_BUMP_ADJUSTED_SCRAPE_CAN_FAIL_WHEN_QUASI_STATIC_PASS 验证更保守 bump 筛选可缩小可行域。
% 功能说明:
%   在静态/准静态 scrape 通过的前提下，增大 bump reserve 使 bump-adjusted scrape 失败。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;
caseDef.rules.enforceRules = false;
caseDef.rules.minStaticGroundClearance = 0.0;
caseDef.targets.enforceTargets = false;
caseDef.targets.minDynamicClearance = 0.0;
caseDef.bumpAdjust.enable = true;
caseDef.bumpAdjust.reserveFront = 0.020;
caseDef.bumpAdjust.reserveRear = 0.020;

res = run_case(caseDef);

assert(res.flags.scrapePassQuasiStatic, 'Expected quasi-static scrape to pass.');
assert(~res.flags.scrapePassBumpAdjusted, 'Expected bump-adjusted scrape to fail.');
assert(res.flags.bumpAdjustedClearanceViolation || ~res.clearance.dynamicClearanceBumpAdjustedPass, ...
    'Expected bump-adjusted scrape failure to come from tighter bump-adjusted clearance.');

fprintf('[PASS] test_bump_adjusted_scrape_can_fail_when_quasi_static_pass\n');
end
