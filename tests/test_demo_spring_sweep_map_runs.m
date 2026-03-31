function test_demo_spring_sweep_map_runs()
%TEST_DEMO_SPRING_SWEEP_MAP_RUNS 验证 demo_spring_sweep_map 可运行。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

set(0, 'DefaultFigureVisible', 'off');
cleanupObj = onCleanup(@() restore_demo_graphics());
close all force;

sweepOut = demo_spring_sweep_map();

assert(isfield(sweepOut, 'classGridQuasiStatic') && isfield(sweepOut, 'classGridBumpAdjusted'), ...
    'Expected demo_spring_sweep_map to return class grids.');
assert(~isempty(sweepOut.summaryTable), 'Expected demo_spring_sweep_map to return a non-empty summaryTable.');

fprintf('[PASS] test_demo_spring_sweep_map_runs\n');
end

function restore_demo_graphics()
close all force;
set(0, 'DefaultFigureVisible', 'on');
end
