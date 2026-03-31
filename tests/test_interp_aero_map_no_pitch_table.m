function test_interp_aero_map_no_pitch_table()
%TEST_INTERP_AERO_MAP_NO_PITCH_TABLE 验证缺少 pitchMomentTable 时仍可运行。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

mapData = struct();
mapData.hfGrid = [0.02, 0.04];
mapData.hrGrid = [0.03, 0.05];
mapData.phiGrid = [-0.10, 0.10];
mapData.betaGrid = [-0.20, 0.20];
mapData.CzTable = 2.0 .* ones(2, 2, 2, 2);
mapData.CdTable = 1.0 .* ones(2, 2, 2, 2);
mapData.frontShareTable = 0.48 .* ones(2, 2, 2, 2);

aeroOut = interp_aero_map(mapData, 0.03, 0.04, 0.00, 0.00, struct('allowFallback', true));

assert(aeroOut.pitchMomentExtra == 0.0, 'Expected pitchMomentExtra=0 when pitchMomentTable is absent.');
assert(~aeroOut.interpFallbackUsed, 'Expected no fallback for finite in-range query.');

fprintf('[PASS] test_interp_aero_map_no_pitch_table\n');
end
