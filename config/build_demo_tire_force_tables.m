function tireData = build_demo_tire_force_tables()
%BUILD_DEMO_TIRE_FORCE_TABLES 构造 V1.5 示例轮胎代理长表数据。
% 功能说明:
%   1) 生成可直接用于 tire.forceModel.sourceType='table_struct' 的示例数据。
%   2) 数据覆盖 pure lateral / pure longitudinal 所需的 Fy/Mz/Fx 长表。
%   3) 数据是概念设计阶段的平滑代理，不代表真实轮胎台架标定结果。
%
% 输入:
%   无
%
% 输出:
%   tireData - 统一示例表格结构，包含：
%              .FyTable(alpha,Fz,gamma,Fy)
%              .MzTable(alpha,Fz,gamma,Mz)
%              .FxTable(kappa,Fz,gamma,Fx)
%              .Meta
%
% 关键物理假设:
%   1) 仅用于 V1.5 首版 table/excel 代理层示例与测试。
%   2) Fy/Fx 峰值随法向载荷变化，且制动能力略高于驱动能力。
%   3) Mz 采用随 alpha 增大逐步衰减的简化 pneumatic trail 代理。
%
% 单位约定:
%   alpha/gamma [deg]，kappa [-]，Fz/Fx/Fy [N]，Mz [N*m]

alphaGridDeg = (-12:2:12).';
gammaGridDeg = [-3; 0; 3];
FzGrid = [350; 500; 650; 800; 950];
kappaGrid = (-0.18:0.03:0.18).';

FyAlpha = [];
FyFz = [];
FyGamma = [];
FyValue = [];

MzAlpha = [];
MzFz = [];
MzGamma = [];
MzValue = [];

FxKappa = [];
FxFz = [];
FxGamma = [];
FxValue = [];

for iGamma = 1:numel(gammaGridDeg)
    gammaDeg = gammaGridDeg(iGamma);
    gammaAbs = abs(gammaDeg);

    for iFz = 1:numel(FzGrid)
        Fz = FzGrid(iFz);

        % 纯侧向峰值代理：随载荷略降，带轻微 camber 增益。
        muYPeak = max(0.95, 1.85 - 3.5e-4 * max(Fz - 650, 0) + 0.015 * gammaAbs);

        for iAlpha = 1:numel(alphaGridDeg)
            alphaDeg = alphaGridDeg(iAlpha);
            alphaRad = deg2rad(alphaDeg);

            Fy = muYPeak * Fz * tanh(11.0 * alphaRad);

            % 简化回正力矩代理：Mz 与 Fy 同步变化，但随大侧偏逐步衰减。
            trail = 0.030 * exp(-10.0 * abs(alphaRad)) + 0.006;
            Mz = -Fy * trail;

            FyAlpha(end+1,1) = alphaDeg; %#ok<AGROW>
            FyFz(end+1,1) = Fz; %#ok<AGROW>
            FyGamma(end+1,1) = gammaDeg; %#ok<AGROW>
            FyValue(end+1,1) = Fy; %#ok<AGROW>

            MzAlpha(end+1,1) = alphaDeg; %#ok<AGROW>
            MzFz(end+1,1) = Fz; %#ok<AGROW>
            MzGamma(end+1,1) = gammaDeg; %#ok<AGROW>
            MzValue(end+1,1) = Mz; %#ok<AGROW>
        end

        % 纯纵向峰值代理：制动能力略高于驱动能力，均随载荷略降。
        muXBrake = max(0.95, 1.90 - 3.0e-4 * max(Fz - 650, 0) + 0.010 * gammaAbs);
        muXDrive = max(0.85, 1.62 - 2.7e-4 * max(Fz - 650, 0) + 0.008 * gammaAbs);

        for iKappa = 1:numel(kappaGrid)
            kappa = kappaGrid(iKappa);
            if kappa < 0
                muXPeak = muXBrake;
            else
                muXPeak = muXDrive;
            end

            Fx = muXPeak * Fz * tanh(10.5 * kappa);

            FxKappa(end+1,1) = kappa; %#ok<AGROW>
            FxFz(end+1,1) = Fz; %#ok<AGROW>
            FxGamma(end+1,1) = gammaDeg; %#ok<AGROW>
            FxValue(end+1,1) = Fx; %#ok<AGROW>
        end
    end
end

tireData = struct();
tireData.FyTable = table(FyAlpha, FyFz, FyGamma, FyValue, ...
    'VariableNames', {'alpha', 'Fz', 'gamma', 'Fy'});
tireData.MzTable = table(MzAlpha, MzFz, MzGamma, MzValue, ...
    'VariableNames', {'alpha', 'Fz', 'gamma', 'Mz'});
tireData.FxTable = table(FxKappa, FxFz, FxGamma, FxValue, ...
    'VariableNames', {'kappa', 'Fz', 'gamma', 'Fx'});

tireData.Meta = struct( ...
    'tireName', 'Demo_V15_Table_Tire', ...
    'source', 'synthetic_proxy', ...
    'pressure', 83000, ...
    'alphaUnit', 'deg', ...
    'gammaUnit', 'deg', ...
    'kappaUnit', 'ratio', ...
    'FzUnit', 'N', ...
    'forceUnit', 'N', ...
    'momentUnit', 'N*m', ...
    'pressureUnit', 'Pa', ...
    'notes', 'Synthetic proxy data for V1.5 demos/tests; not a measured tire set');
end
