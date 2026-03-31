function test_interp_aero_map_basic()
%TEST_INTERP_AERO_MAP_BASIC 验证 4D 气动地图 linear 插值与输出字段。
% 功能说明:
%   1) 构造可解析的 4D 线性地图。
%   2) 验证 interp_aero_map 正常返回 Cz/Cd/frontShare/pitchMomentExtra。
%   3) 验证 clamp/fallback 透明标记字段完整。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

hfGrid = [0.02, 0.04];
hrGrid = [0.03, 0.05];
phiGrid = [-0.10, 0.10];
betaGrid = [-0.20, 0.20];
[HF, HR, PHI, BETA] = ndgrid(hfGrid, hrGrid, phiGrid, betaGrid);

mapData = struct();
mapData.hfGrid = hfGrid;
mapData.hrGrid = hrGrid;
mapData.phiGrid = phiGrid;
mapData.betaGrid = betaGrid;
mapData.CzTable = 2.0 + 4.0 .* HF + 3.0 .* HR + 0.5 .* PHI - 0.2 .* BETA;
mapData.CdTable = 1.0 + 0.3 .* HF + 0.2 .* HR + 0.1 .* PHI + 0.05 .* BETA;
mapData.frontShareTable = 0.45 + 0.2 .* (HR - HF) + 0.02 .* PHI - 0.01 .* BETA;
mapData.pitchMomentTable = 5.0 .* HF - 3.0 .* HR + 2.0 .* PHI + 0.5 .* BETA;

hfQ = 0.03;
hrQ = 0.04;
phiQ = 0.00;
betaQ = 0.10;

aeroOut = interp_aero_map(mapData, hfQ, hrQ, phiQ, betaQ, struct('allowFallback', true));

expectedCz = 2.0 + 4.0 .* hfQ + 3.0 .* hrQ + 0.5 .* phiQ - 0.2 .* betaQ;
expectedCd = 1.0 + 0.3 .* hfQ + 0.2 .* hrQ + 0.1 .* phiQ + 0.05 .* betaQ;
expectedFrontShare = 0.45 + 0.2 .* (hrQ - hfQ) + 0.02 .* phiQ - 0.01 .* betaQ;
expectedPitchMoment = 5.0 .* hfQ - 3.0 .* hrQ + 2.0 .* phiQ + 0.5 .* betaQ;

requiredFields = { ...
    'Cz', 'Cd', 'frontShare', 'pitchMomentExtra', ...
    'mapClampedAny', 'mapClamped', 'hfClamped', 'hrClamped', 'phiClamped', 'betaClamped', ...
    'interpFallbackUsed', 'mapClampInfo'};
for i = 1:numel(requiredFields)
    assert(isfield(aeroOut, requiredFields{i}), 'Missing field: %s', requiredFields{i});
end

assert(abs(aeroOut.Cz - expectedCz) < 1e-12, 'Unexpected Cz from linear interpolation.');
assert(abs(aeroOut.Cd - expectedCd) < 1e-12, 'Unexpected Cd from linear interpolation.');
assert(abs(aeroOut.frontShare - expectedFrontShare) < 1e-12, 'Unexpected frontShare from linear interpolation.');
assert(abs(aeroOut.pitchMomentExtra - expectedPitchMoment) < 1e-12, 'Unexpected pitchMomentExtra from linear interpolation.');
assert(~aeroOut.mapClampedAny, 'Expected mapClampedAny=false for in-range query.');
assert(~aeroOut.interpFallbackUsed, 'Expected interpFallbackUsed=false for healthy linear interpolation.');

fprintf('[PASS] test_interp_aero_map_basic\n');
end
