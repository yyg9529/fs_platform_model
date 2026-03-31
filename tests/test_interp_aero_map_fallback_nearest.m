function test_interp_aero_map_fallback_nearest()
%TEST_INTERP_AERO_MAP_FALLBACK_NEAREST 验证 linear 非有限值时回退到 nearest。
% 功能说明:
%   1) 构造含局部 NaN 的 4D 气动地图。
%   2) 让 linear 结果变成非有限值。
%   3) 验证 allowFallback=true 时，函数显式切换到 nearest 并打标。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

mapData = struct();
mapData.hfGrid = [0.0, 1.0];
mapData.hrGrid = [0.0, 1.0];
mapData.phiGrid = [0.0, 1.0];
mapData.betaGrid = [0.0, 1.0];

mapData.CzTable = 10 .* ones(2, 2, 2, 2);
mapData.CdTable = 20 .* ones(2, 2, 2, 2);
mapData.frontShareTable = 0.60 .* ones(2, 2, 2, 2);
mapData.pitchMomentTable = 30 .* ones(2, 2, 2, 2);

mapData.CzTable(1, 1, 1, 1) = 5.0;
mapData.CdTable(1, 1, 1, 1) = 6.0;
mapData.frontShareTable(1, 1, 1, 1) = 0.45;
mapData.pitchMomentTable(1, 1, 1, 1) = 7.0;

mapData.CzTable(2, 2, 2, 2) = nan;

aeroOut = interp_aero_map(mapData, 0.10, 0.10, 0.10, 0.10, struct('allowFallback', true));

assert(aeroOut.interpFallbackUsed, 'Expected fallback to be used when linear result is non-finite.');
assert(abs(aeroOut.Cz - 5.0) < 1e-12, 'Expected nearest fallback Cz from the nearest corner.');
assert(abs(aeroOut.Cd - 6.0) < 1e-12, 'Expected nearest fallback Cd from the nearest corner.');
assert(abs(aeroOut.frontShare - 0.45) < 1e-12, 'Expected nearest fallback frontShare from the nearest corner.');
assert(abs(aeroOut.pitchMomentExtra - 7.0) < 1e-12, 'Expected nearest fallback pitchMomentExtra from the nearest corner.');
assert(contains(lower(aeroOut.mapClampInfo.fallbackReason), 'non-finite'), ...
    'Expected fallback reason to mention non-finite linear interpolation result.');

fprintf('[PASS] test_interp_aero_map_fallback_nearest\n');
end
