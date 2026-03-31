function test_run_batch_summary_with_tire()
%TEST_RUN_BATCH_SUMMARY_WITH_TIRE tire.forceModel.enable=true 时 run_batch summary 新字段存在。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseA = build_test_tire_proxy_case();
caseB = build_test_tire_proxy_case();
caseB.meta.name = 'FS_Target_2026_tire_alt';
caseB.tireOp.alpha = 6.0;
caseB.tireOp.kappa = -0.04;

batch = run_batch({caseA, caseB});
vars = string(batch.summaryTable.Properties.VariableNames);
req = [ ...
    "tireEvalFailed", "tireOutOfRange", "contactLostAny", ...
    "FyFrontTotal", "FyRearTotal", "FxFrontTotal", "FxRearTotal", ...
    "frontFyShare", "rearFyShare", "balanceIndex", ...
    "peakMarginFront", "peakMarginRear", "maxAbsMuY", "maxAbsMuX"];

assert(all(ismember(req, vars)), 'Expected V1.5 tire summary fields in run_batch output.');
assert(height(batch.summaryTable) == 2, 'Expected two rows in batch summary.');

fprintf('[PASS] test_run_batch_summary_with_tire\n');
end
