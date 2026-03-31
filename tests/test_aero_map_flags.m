function test_aero_map_flags()
%TEST_AERO_MAP_FLAGS 气动插值 clamp/fallback 标志测试。
% 功能说明:
%   1) 触发线性插值非有限值，验证 fallback 标志。
%   2) 触发查询越界，验证 clamp 标志。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

mapData = struct();
mapData.hfGrid = [0, 1];
mapData.hrGrid = [0, 1];
mapData.phiGrid = [-0.5, 0.5];
mapData.betaGrid = [-0.5, 0.5];

mapData.CzTable = ones(2,2,2,2);
mapData.CdTable = 0.8 .* ones(2,2,2,2);
mapData.frontShareTable = 0.5 .* ones(2,2,2,2);

% 仅放一个 NaN，线性插值会传染为 NaN，触发 fallback
mapData.CzTable(2,2,2,2) = nan;

caseDef.aero.mapType = 'table_lookup';
caseDef.aero.mapData = mapData;
caseDef.aero.nominalRef = struct('VGrid', [0; 1], 'FzNominal', [0; 0], 'frontShareNominal', [0.5; 0.5]);

caseDef.man.V = 0.0;
caseDef.man.ax = 0.0;
caseDef.man.ay = 0.0;
caseDef.man.beta = 0.0;

caseDef.ref.hAeroF0 = 0.01;
caseDef.ref.hAeroR0 = 0.01;

resFallback = run_case(caseDef);
assert(resFallback.flags.interpFallbackUsed, 'Expected interpFallbackUsed=true for NaN linear interpolation result.');

% 再构造一份无 NaN 的地图用于越界查询，验证 clamp 标志
caseClamp = caseDef;
caseClamp.aero.mapData.CzTable = ones(2,2,2,2);
caseClamp.ref.hAeroF0 = 2.0;
caseClamp.ref.hAeroR0 = 2.0;
resClamp = run_case(caseClamp);

assert(resClamp.flags.mapClampedAny, 'Expected mapClampedAny=true when query is out of map range.');
assert(resClamp.flags.hfClamped && resClamp.flags.hrClamped, 'Expected hf/hr clamp flags to be true.');

fprintf('[PASS] test_aero_map_flags\n');
end
