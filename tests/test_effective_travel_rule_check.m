function test_effective_travel_rule_check()
%TEST_EFFECTIVE_TRAVEL_RULE_CHECK effective total travel 规则层测试。
% 功能说明:
%   将规则阈值设在 nominal 总轮跳与 effective 总轮跳之间，
%   验证 usableWheelTravelPass 由 effective travel 决定。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseBase = build_case_2026_target();
caseBase.rules.enforceRules = false;
caseBase.targets.enforceTargets = false;

refRes = run_case(caseBase);
nominalTotal = min(caseBase.sus.jounceMax(:) + caseBase.sus.droopMax(:));
effectiveTotal = refRes.rules.minEffectiveTotalTravel;
assert(effectiveTotal < nominalTotal - 1e-6, ...
    'Expected effective travel to be smaller than nominal wheel-limit travel.');

threshold = 0.5 * (nominalTotal + effectiveTotal);

caseRule = caseBase;
caseRule.rules.enforceRules = true;
caseRule.targets.enforceTargets = false;
caseRule.rules.minStaticGroundClearance = 0.0;
caseRule.rules.minJounce = 0.0;
caseRule.rules.minUsableWheelTravelTotal = threshold;
res = run_case(caseRule);

assert(nominalTotal > threshold, 'Expected nominal total travel above threshold.');
assert(res.rules.minEffectiveTotalTravel < threshold, 'Expected effective total travel below threshold.');
assert(~res.rules.usableWheelTravelPass, ...
    'Expected usableWheelTravelPass=false when threshold exceeds effective total travel.');

fprintf('[PASS] test_effective_travel_rule_check\n');
end
