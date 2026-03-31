function figHandle = plot_tire_table_scan(scanSource)
%PLOT_TIRE_TABLE_SCAN 可视化 V1.5 轮胎 scan 或单 operating point 结果。
% 功能说明:
%   1) 若输入包含 results.tire.scan.enable=true，则绘制 scan 曲线。
%   2) 若输入只有单点结果，则绘制四角点 Fx/Fy/Mz/utilization 条形图。
%   3) 图形只服务于概念设计阶段的轮胎代理层展示，不代表完整操稳仿真。
%
% 输入:
%   scanSource - run_case 结果结构，或直接传 results.tire.scan
%
% 输出:
%   figHandle - figure 句柄
%
% 关键物理假设:
%   1) scan 中的 Fz 固定来自同一个平台 operating point。
%   2) 若为 brake-in-turn / accel-out，combined 结果可能来自 proxy 近似。
%
% 单位约定:
%   绘图默认显示 alpha[deg] 或 kappa[-]；力[N]；力矩[N*m]

if isfield(scanSource, 'tire')
    results = scanSource;
    scanData = results.tire.scan;
else
    results = struct();
    scanData = scanSource;
end

figHandle = figure('Name', 'V1.5 Tire Table Scan', 'Color', 'w');

if isstruct(scanData) && isfield(scanData, 'enable') && logical(scanData.enable)
    xVal = scanData.valuesSI(:);
    xLabel = sprintf('%s [%s]', scanData.field, scanData.unit);
    if strcmpi(scanData.field, 'alpha')
        if strcmpi(scanData.unit, 'deg')
            xVal = rad2deg(scanData.valuesSI(:));
        end
    elseif strcmpi(scanData.field, 'gamma')
        if strcmpi(scanData.unit, 'deg')
            xVal = rad2deg(scanData.valuesSI(:));
        end
    end

    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(xVal, scanData.FyFrontTotal, 'LineWidth', 1.6); hold on;
    plot(xVal, scanData.FyRearTotal, 'LineWidth', 1.6);
    grid on;
    xlabel(xLabel);
    ylabel('Axle Fy [N]');
    legend({'Front', 'Rear'}, 'Location', 'best');
    title('Lateral Force Split');

    nexttile;
    plot(xVal, scanData.FxFrontTotal, 'LineWidth', 1.6); hold on;
    plot(xVal, scanData.FxRearTotal, 'LineWidth', 1.6);
    grid on;
    xlabel(xLabel);
    ylabel('Axle Fx [N]');
    legend({'Front', 'Rear'}, 'Location', 'best');
    title('Longitudinal Force Split');

    nexttile;
    plot(xVal, max(scanData.utilization(1:2, :), [], 1, 'omitnan'), 'LineWidth', 1.6); hold on;
    plot(xVal, max(scanData.utilization(3:4, :), [], 1, 'omitnan'), 'LineWidth', 1.6);
    grid on;
    xlabel(xLabel);
    ylabel('Utilization [-]');
    legend({'Front Peak', 'Rear Peak'}, 'Location', 'best');
    title('Peak Utilization');

    nexttile;
    plot(xVal, scanData.balanceIndex, 'LineWidth', 1.6);
    grid on;
    xlabel(xLabel);
    ylabel('Balance Index [-]');
    title('Front Utilization - Rear Utilization');

else
    if ~isfield(results, 'tire')
        error('plot_tire_table_scan:MissingInput', ...
            'Input must be a run_case result or a scan struct with enable=true.');
    end

    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    cornerLabels = categorical({'FL', 'FR', 'RL', 'RR'});

    nexttile;
    bar(cornerLabels, results.tire.forces.Fy);
    grid on;
    ylabel('Fy [N]');
    title('Corner Lateral Force');

    nexttile;
    bar(cornerLabels, results.tire.forces.Fx);
    grid on;
    ylabel('Fx [N]');
    title('Corner Longitudinal Force');

    nexttile;
    bar(cornerLabels, results.tire.forces.Mz);
    grid on;
    ylabel('Mz [N*m]');
    title('Corner Aligning Moment');

    nexttile;
    bar(cornerLabels, utilization_or_default(results));
    grid on;
    ylabel('Utilization [-]');
    title('Corner Utilization');
end
end

function util = utilization_or_default(results)
%UTILIZATION_OR_DEFAULT 从 results.tire 中安全提取 corner utilization。
if isfield(results.tire, 'scan') && isstruct(results.tire.scan) && logical(results.tire.scan.enable)
    util = max(results.tire.scan.utilization, [], 2, 'omitnan');
elseif isfield(results.tire, 'balance') && isfield(results.tire, 'validity')
    if isfield(results.tire, 'forces') && isfield(results.tire.forces, 'Fx') ...
            && isfield(results.tire.forces, 'Fy') && isfield(results.tire.forces, 'FxCap') ...
            && isfield(results.tire.forces, 'FyCap')
        util = max(abs(results.tire.forces.Fx) ./ max(abs(results.tire.forces.FxCap), eps), ...
            abs(results.tire.forces.Fy) ./ max(abs(results.tire.forces.FyCap), eps));
    else
        util = nan(4,1);
    end
else
    util = nan(4,1);
end
end
