function test_demo_tire_table_pure_lateral_runs()
%TEST_DEMO_TIRE_TABLE_PURE_LATERAL_RUNS 验证 pure lateral demo 可正常运行。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

figState = get(0, 'DefaultFigureVisible');
cleanupObj = onCleanup(@() set(0, 'DefaultFigureVisible', figState)); %#ok<NASGU>
set(0, 'DefaultFigureVisible', 'off');

results = demo_tire_table_pure_lateral();
assert(results.flags.tireForceModelEnabled, 'Expected tire force model to be enabled in demo.');
assert(results.tire.scan.enable, 'Expected alpha scan output in pure lateral demo.');
assert(~results.flags.tireEvalFailed, 'Expected demo to finish without tire evaluation failure.');

fprintf('[PASS] test_demo_tire_table_pure_lateral_runs\n');
end
