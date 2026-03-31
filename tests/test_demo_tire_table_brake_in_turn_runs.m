function test_demo_tire_table_brake_in_turn_runs()
%TEST_DEMO_TIRE_TABLE_BRAKE_IN_TURN_RUNS 验证 brake-in-turn demo 可正常运行。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

figState = get(0, 'DefaultFigureVisible');
cleanupObj = onCleanup(@() set(0, 'DefaultFigureVisible', figState)); %#ok<NASGU>
set(0, 'DefaultFigureVisible', 'off');

results = demo_tire_table_brake_in_turn();
assert(results.flags.tireForceModelEnabled, 'Expected tire force model to be enabled in demo.');
assert(results.tire.scan.enable, 'Expected kappa scan output in brake-in-turn demo.');
assert(~results.flags.tireEvalFailed, 'Expected demo to finish without tire evaluation failure.');

fprintf('[PASS] test_demo_tire_table_brake_in_turn_runs\n');
end
