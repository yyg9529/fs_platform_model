function test_rule_checks()
%TEST_RULE_CHECKS 赛规约束层判定测试。
% 功能说明:
%   验证 rulePass 与 enforceRules 的行为：
%   1) enforceRules=true 时，规则失败应使 rulePass=false
%   2) enforceRules=false 时，保留 rulePassRaw 但不阻断 rulePass

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.targets.enforceTargets = false;
caseDef.solver.strictTravelViolation = false;

% 人为设置非常苛刻的静态离地高下限，触发规则失败
caseDef.rules.enforceRules = true;
caseDef.rules.minStaticGroundClearance = 0.080;
resFail = run_case(caseDef);

assert(~resFail.rules.staticGroundClearancePass, 'Expected staticGroundClearancePass=false.');
assert(~resFail.rules.rulePassRaw, 'Expected rulePassRaw=false.');
assert(~resFail.flags.rulePass, 'Expected flag rulePass=false when enforceRules=true.');

% 关闭规则强制后，raw 仍失败，但 rulePass 应放行
caseNoEnforce = caseDef;
caseNoEnforce.rules.enforceRules = false;
resNoEnforce = run_case(caseNoEnforce);

assert(~resNoEnforce.rules.rulePassRaw, 'Expected rulePassRaw still false when enforceRules=false.');
assert(resNoEnforce.flags.rulePass, 'Expected rulePass=true when rules are not enforced.');

fprintf('[PASS] test_rule_checks\n');
end
