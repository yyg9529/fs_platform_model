function test_run_batch_summary_fields_v104()
%TEST_RUN_BATCH_SUMMARY_FIELDS_V104 验证 run_batch 已包含 V1.0.4 新字段。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseA = build_case_2026_target();
caseA.rules.enforceRules = false;
caseA.targets.enforceTargets = false;
caseA.tire.mode = 'fixed';
caseA.tire.ktFront = 220000;
caseA.tire.ktRear = 240000;
caseA.bumpAdjust.enable = true;
caseA.bumpAdjust.reserveFront = 0.004;
caseA.bumpAdjust.reserveRear = 0.003;

caseB = caseA;
caseB.meta.name = 'FS_Target_2026_range';
caseB.tire.mode = 'range';
caseB.tire.ktFrontRange = [190000, 220000, 250000];
caseB.tire.ktRearRange = [210000, 240000, 270000];

batch = run_batch({caseA, caseB});
vars = string(batch.summaryTable.Properties.VariableNames);
req = [ ...
    "FrontSpring", "RearSpring", "hDynamicMinBumpAdjusted", ...
    "AeroPlatformPass", "ScrapePassQuasiStatic", "ScrapePassBumpAdjusted", ...
    "mapClassQuasiStatic", "mapClassBumpAdjusted", ...
    "staticGroundClearancePass", "dynamicClearancePass", "dynamicClearanceBumpAdjustedPass", ...
    "aeroLossPass", "frontShareMigrationPass", ...
    "effectiveJounce", "effectiveDroop", "effectiveTotalTravel"];

assert(all(ismember(req, vars)), 'Expected V1.0.4 summary fields in run_batch output.');
assert(height(batch.summaryTable) == 2, 'Expected two rows in batch summary.');

fprintf('[PASS] test_run_batch_summary_fields_v104\n');
end
