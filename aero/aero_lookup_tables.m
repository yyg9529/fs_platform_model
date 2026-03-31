function [mapData, nominalRef] = aero_lookup_tables()
%AERO_LOOKUP_TABLES Build a minimal runnable placeholder aero map.
% 功能:
%   生成可运行的 4D 气动查表数据，供 table_lookup 模式使用。
%
% 说明:
%   该数据仅用于 V1.0 示例跑通，不代表实测风洞标定结果。

hfGrid = linspace(0.015, 0.055, 5);           % 前参考车高 [m]
hrGrid = linspace(0.020, 0.070, 6);           % 后参考车高 [m]
phiGrid = deg2rad_safe([-4, -2, 0, 2, 4]);    % 侧倾角 [rad]
betaGrid = deg2rad_safe([-6, -3, 0, 3, 6]);   % 侧偏角 [rad]

[HF, HR, PHI, BETA] = ndgrid(hfGrid, hrGrid, phiGrid, betaGrid);

% 占位经验模型:
% Cz 随车高增大而下降，随姿态失配(|phi|, |beta|)下降
Cz0 = 2.7;
Cz = Cz0 .* (1 - 3.0 .* (HF - 0.025) - 2.2 .* (HR - 0.035) ...
    - 0.12 .* abs(PHI) ./ deg2rad_safe(1) - 0.03 .* abs(BETA) ./ deg2rad_safe(1));
Cz = max(Cz, 0.2);

Cd0 = 1.05;
Cd = Cd0 .* (1 + 0.35 .* (HF - 0.025) + 0.25 .* (HR - 0.035) ...
    + 0.02 .* abs(BETA) ./ deg2rad_safe(1));
Cd = max(Cd, 0.4);

% 前轴下压力占比:
% 前低后高时前轴占比上升；姿态越大略后移
frontShare = 0.46 + 0.70 .* (HR - HF) - 0.003 .* abs(PHI) ./ deg2rad_safe(1);
frontShare = clamp_value(frontShare, 0.30, 0.70);

pitchMomentTable = zeros(size(Cz)); % 额外俯仰力矩占位 [N*m]

mapData = struct();
mapData.hfGrid = hfGrid;
mapData.hrGrid = hrGrid;
mapData.phiGrid = phiGrid;
mapData.betaGrid = betaGrid;
mapData.CzTable = Cz;
mapData.CdTable = Cd;
mapData.frontShareTable = frontShare;
mapData.pitchMomentTable = pitchMomentTable;

% 名义参考曲线（用于损失和配平漂移指标）
VGrid = (0:5:40).';
FzNominal = [0; 120; 480; 1080; 1920; 3000; 4320; 5880; 7680];
frontShareNominal = [0.470; 0.470; 0.468; 0.466; 0.464; 0.462; 0.460; 0.458; 0.456];

nominalRef = struct();
nominalRef.VGrid = VGrid;
nominalRef.FzNominal = FzNominal;
nominalRef.frontShareNominal = frontShareNominal;
end
