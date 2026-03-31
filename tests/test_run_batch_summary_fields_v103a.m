function test_run_batch_summary_fields_v103a()
%TEST_RUN_BATCH_SUMMARY_FIELDS_V103A batch summary 字段冒烟测试。
% 功能说明:
%   验证 run_batch 的 summaryTable 已包含 V1.0.3a 需要的关键筛选列。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseA = build_case_2026_target();
caseA.rules.enforceRules = false;
caseA.targets.enforceTargets = false;

caseB = caseA;
caseB.meta.name = 'FS_Target_2026_range';
caseB.tire.mode = 'range';
caseB.tire.ktFrontRange = [190000, 220000, 250000];
caseB.tire.ktRearRange = [210000, 240000, 270000];

batch = run_batch({caseA, caseB});
vars = string(batch.summaryTable.Properties.VariableNames);
req = [ ...
    "hStaticMin", "hDynamicMin", "hMin", ...
    "StaticGroundClearancePass", "DynamicClearancePass", ...
    "EffectiveJounce", "EffectiveTotalTravel", ...
    "RulePass", "DesignPass", "Feasible", ...
    "TireMode", "KtCase", "KtBand"];

assert(all(ismember(req, vars)), 'Expected V1.0.3a summary fields in run_batch output.');
assert(height(batch.summaryTable) == 2, 'Expected two rows in batch summary.');

fprintf('[PASS] test_run_batch_summary_fields_v103a\n');
end
