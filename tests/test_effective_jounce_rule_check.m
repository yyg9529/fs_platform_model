function test_effective_jounce_rule_check()
%TEST_EFFECTIVE_JOUNCE_RULE_CHECK effective jounce 规则层测试。
% 功能说明:
%   将 minJounce 阈值设在 nominal jounce 与 effective jounce 之间，
%   验证 minJouncePass 由 effective jounce 决定。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseBase = build_case_2026_target();
caseBase.rules.enforceRules = false;
caseBase.targets.enforceTargets = false;

refRes = run_case(caseBase);
nominalJounce = min(caseBase.sus.jounceMax(:));
effectiveJounce = refRes.rules.minEffectiveJounce;
assert(effectiveJounce < nominalJounce - 1e-6, ...
    'Expected effective jounce to be smaller than nominal jounce limit.');

threshold = 0.5 * (nominalJounce + effectiveJounce);

caseRule = caseBase;
caseRule.rules.enforceRules = true;
caseRule.targets.enforceTargets = false;
caseRule.rules.minStaticGroundClearance = 0.0;
caseRule.rules.minUsableWheelTravelTotal = 0.0;
caseRule.rules.minJounce = threshold;
res = run_case(caseRule);

assert(nominalJounce > threshold, 'Expected nominal jounce above threshold.');
assert(res.rules.minEffectiveJounce < threshold, 'Expected effective jounce below threshold.');
assert(~res.rules.minJouncePass, ...
    'Expected minJouncePass=false when threshold exceeds effective jounce.');

fprintf('[PASS] test_effective_jounce_rule_check\n');
end
