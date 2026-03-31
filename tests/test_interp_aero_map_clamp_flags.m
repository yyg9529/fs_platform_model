function test_interp_aero_map_clamp_flags()
%TEST_INTERP_AERO_MAP_CLAMP_FLAGS 验证越界查询时的 clamp 标志与信息。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

mapData = struct();
mapData.hfGrid = [0.02, 0.04];
mapData.hrGrid = [0.03, 0.05];
mapData.phiGrid = [-0.10, 0.10];
mapData.betaGrid = [-0.20, 0.20];
mapData.CzTable = ones(2, 2, 2, 2);
mapData.CdTable = 0.8 .* ones(2, 2, 2, 2);
mapData.frontShareTable = 0.5 .* ones(2, 2, 2, 2);

aeroOut = interp_aero_map(mapData, 0.01, 0.08, -0.50, 0.60, struct('allowFallback', true));

assert(aeroOut.mapClampedAny, 'Expected mapClampedAny=true for out-of-range query.');
assert(aeroOut.mapClamped, 'Expected compatibility field mapClamped=true.');
assert(aeroOut.hfClamped, 'Expected hf clamp flag.');
assert(aeroOut.hrClamped, 'Expected hr clamp flag.');
assert(aeroOut.phiClamped, 'Expected phi clamp flag.');
assert(aeroOut.betaClamped, 'Expected beta clamp flag.');

assert(abs(aeroOut.mapClampInfo.hfClampedTo - 0.02) < 1e-12, 'Unexpected hf clamp value.');
assert(abs(aeroOut.mapClampInfo.hrClampedTo - 0.05) < 1e-12, 'Unexpected hr clamp value.');
assert(abs(aeroOut.mapClampInfo.phiClampedTo + 0.10) < 1e-12, 'Unexpected phi clamp value.');
assert(abs(aeroOut.mapClampInfo.betaClampedTo - 0.20) < 1e-12, 'Unexpected beta clamp value.');

fprintf('[PASS] test_interp_aero_map_clamp_flags\n');
end
