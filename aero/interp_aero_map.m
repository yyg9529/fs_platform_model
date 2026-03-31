function aeroOut = interp_aero_map(mapData, hf, hr, phi, beta, options)
%INTERP_AERO_MAP 执行 4D 气动地图插值（hf, hr, phi, beta）。
% 功能说明:
%   该函数是 table_lookup 气动映射的 4D 插值层，查询维度分别为：
%   前参考车高 hf、后参考车高 hr、车身侧倾 phi、车身侧偏 beta。
%   本次修复的重点是“兼容性 + 透明 flag”，不是改变原有气动物理模型。
%
% 输入:
%   mapData - 含网格与表格字段的结构体
%   hf/hr   - 前后参考车高 [m]
%   phi     - 侧倾角 [rad]
%   beta    - 侧偏角 [rad]
%   options.allowFallback - true: linear 失败时允许 nearest fallback
%
% 输出:
%   aeroOut - 结构体，至少包含：
%             Cz/Cd/frontShare/pitchMomentExtra
%             mapClampedAny/mapClamped
%             hfClamped/hrClamped/phiClamped/betaClamped
%             interpFallbackUsed/mapClampInfo
%
% 工程说明:
%   1) clamp 的物理意义是：查询点超出标定网格时，退回到最近边界，避免无定义外推。
%   2) fallback 的工程意义是：linear 插值失败或返回非有限值时，显式降级到 nearest，
%      同时保留透明标记，避免“算出来了但不知道怎么算出来”的黑箱结果。
%   3) pitchMomentExtra 是附加俯仰力矩项；若无 pitchMomentTable，则返回 0。

if nargin < 6 || isempty(options)
    options = struct();
end
if ~isfield(options, 'allowFallback') || isempty(options.allowFallback)
    options.allowFallback = true;
end
allowFallback = logical(options.allowFallback);

required = {'hfGrid', 'hrGrid', 'phiGrid', 'betaGrid', 'CzTable', 'CdTable', 'frontShareTable'};
for i = 1:numel(required)
    fieldName = required{i};
    if ~isfield(mapData, fieldName) || isempty(mapData.(fieldName))
        error('interp_aero_map:MissingField', 'Missing required mapData.%s.', fieldName);
    end
end

hfGrid = double(mapData.hfGrid(:));
hrGrid = double(mapData.hrGrid(:));
phiGrid = double(mapData.phiGrid(:));
betaGrid = double(mapData.betaGrid(:));

hfMin = min(hfGrid);
hfMax = max(hfGrid);
hrMin = min(hrGrid);
hrMax = max(hrGrid);
phiMin = min(phiGrid);
phiMax = max(phiGrid);
betaMin = min(betaGrid);
betaMax = max(betaGrid);

clampScalar = @(x, lo, hi) min(max(double(x), double(lo)), double(hi));

hfQ = clampScalar(hf, hfMin, hfMax);
hrQ = clampScalar(hr, hrMin, hrMax);
phiQ = clampScalar(phi, phiMin, phiMax);
betaQ = clampScalar(beta, betaMin, betaMax);

hfClamped = (hfQ ~= double(hf));
hrClamped = (hrQ ~= double(hr));
phiClamped = (phiQ ~= double(phi));
betaClamped = (betaQ ~= double(beta));
mapClampedAny = hfClamped || hrClamped || phiClamped || betaClamped;

hasPitchMomentTable = isfield(mapData, 'pitchMomentTable') && ~isempty(mapData.pitchMomentTable);

interpFallbackUsed = false;
fallbackReason = '';

try
    Cz = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.CzTable, hfQ, hrQ, phiQ, betaQ, 'linear');
    Cd = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.CdTable, hfQ, hrQ, phiQ, betaQ, 'linear');
    frontShare = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.frontShareTable, ...
        hfQ, hrQ, phiQ, betaQ, 'linear');

    if hasPitchMomentTable
        pitchMomentExtra = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.pitchMomentTable, ...
            hfQ, hrQ, phiQ, betaQ, 'linear');
    else
        pitchMomentExtra = 0.0;
    end
catch ME
    if ~allowFallback
        error('interp_aero_map:InterpFailed', 'Linear interpolation failed: %s', ME.message);
    end

    interpFallbackUsed = true;
    fallbackReason = sprintf('linear interpolation failed: %s', ME.message);

    try
        Cz = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.CzTable, hfQ, hrQ, phiQ, betaQ, 'nearest');
        Cd = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.CdTable, hfQ, hrQ, phiQ, betaQ, 'nearest');
        frontShare = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.frontShareTable, ...
            hfQ, hrQ, phiQ, betaQ, 'nearest');

        if hasPitchMomentTable
            pitchMomentExtra = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.pitchMomentTable, ...
                hfQ, hrQ, phiQ, betaQ, 'nearest');
        else
            pitchMomentExtra = 0.0;
        end
    catch ME2
        error('interp_aero_map:NearestFallbackFailed', 'Nearest fallback failed: %s', ME2.message);
    end
end

if any(~isfinite([Cz, Cd, frontShare, pitchMomentExtra]))
    if ~interpFallbackUsed
        if ~allowFallback
            error('interp_aero_map:NonFiniteLinearResult', ...
                'Linear interpolation returned non-finite values (hf=%.6g, hr=%.6g, phi=%.6g, beta=%.6g).', ...
                hfQ, hrQ, phiQ, betaQ);
        end

        interpFallbackUsed = true;
        fallbackReason = 'linear interpolation returned non-finite values';

        try
            Cz = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.CzTable, hfQ, hrQ, phiQ, betaQ, 'nearest');
            Cd = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.CdTable, hfQ, hrQ, phiQ, betaQ, 'nearest');
            frontShare = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.frontShareTable, ...
                hfQ, hrQ, phiQ, betaQ, 'nearest');

            if hasPitchMomentTable
                pitchMomentExtra = interpn(hfGrid, hrGrid, phiGrid, betaGrid, mapData.pitchMomentTable, ...
                    hfQ, hrQ, phiQ, betaQ, 'nearest');
            else
                pitchMomentExtra = 0.0;
            end
        catch ME
            error('interp_aero_map:NearestFallbackFailed', 'Nearest fallback failed: %s', ME.message);
        end
    end

    if any(~isfinite([Cz, Cd, frontShare, pitchMomentExtra]))
        error('interp_aero_map:NearestFallbackNonFinite', ...
            'Nearest fallback still returned non-finite values (hf=%.6g, hr=%.6g, phi=%.6g, beta=%.6g).', ...
            hfQ, hrQ, phiQ, betaQ);
    end
end

Cz = max(0.0, double(Cz));
Cd = max(0.0, double(Cd));
frontShare = min(max(double(frontShare), 0.0), 1.0);
pitchMomentExtra = double(pitchMomentExtra);

aeroOut = struct();
aeroOut.Cz = Cz;
aeroOut.Cd = Cd;
aeroOut.frontShare = frontShare;
aeroOut.pitchMomentExtra = pitchMomentExtra;
aeroOut.mapClampedAny = mapClampedAny;
aeroOut.mapClamped = mapClampedAny;
aeroOut.hfClamped = hfClamped;
aeroOut.hrClamped = hrClamped;
aeroOut.phiClamped = phiClamped;
aeroOut.betaClamped = betaClamped;
aeroOut.interpFallbackUsed = interpFallbackUsed;
aeroOut.mapClampInfo = struct( ...
    'hfRaw', double(hf), 'hfClampedTo', hfQ, 'hfClampedFlag', hfClamped, ...
    'hrRaw', double(hr), 'hrClampedTo', hrQ, 'hrClampedFlag', hrClamped, ...
    'phiRaw', double(phi), 'phiClampedTo', phiQ, 'phiClampedFlag', phiClamped, ...
    'betaRaw', double(beta), 'betaClampedTo', betaQ, 'betaClampedFlag', betaClamped, ...
    'allowFallback', allowFallback, ...
    'fallbackReason', fallbackReason);
end
