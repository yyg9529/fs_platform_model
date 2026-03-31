function test_static_clearance_rule_uses_static_values()
%TEST_STATIC_CLEARANCE_RULE_USES_STATIC_VALUES 静态离地高规则层测试。
% 功能说明:
%   构造“静态通过、动态低于阈值”的场景，验证 rules 仍按静态值判定。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseBase = build_case_2026_target();
caseBase.tire.mode = 'fixed';
caseBase.tire.ktFront = 220000;
caseBase.tire.ktRear = 240000;
caseBase.rules.enforceRules = false;
caseBase.targets.enforceTargets = false;
caseBase.man.V = 35.0;
caseBase.man.ax = -4.0;
caseBase.man.ay = 11.0;

refRes = run_case(caseBase);
assert(refRes.clearance.hStaticMin > refRes.clearance.hDynamicMin + 1e-6, ...
    'Expected static clearance to be larger than dynamic clearance in loaded case.');

threshold = 0.5 * (refRes.clearance.hStaticMin + refRes.clearance.hDynamicMin);

caseRule = caseBase;
caseRule.rules.enforceRules = true;
caseRule.rules.minStaticGroundClearance = threshold;
res = run_case(caseRule);

assert(res.clearance.hStaticMin > threshold, 'Expected static clearance above threshold.');
assert(res.clearance.hDynamicMin < threshold, 'Expected dynamic clearance below threshold.');
assert(res.rules.staticGroundClearancePass, ...
    'Expected rule layer to use static clearance rather than dynamic clearance.');

fprintf('[PASS] test_static_clearance_rule_uses_static_values\n');
end
