function fig = plot_corner_loads(results)
%PLOT_CORNER_LOADS 角点载荷与行程检查图。
% 功能说明:
%   在同一图中显示：
%   1) 静态/动态角点法向载荷
%   2) wheel travel（jounce/droop）
%   3) shock 使用率
%   4) shock 压缩/回弹 margin
%
% 输入:
%   results - run_case 输出结构体
%
% 输出:
%   fig - 图窗句柄
%
% 关键物理假设:
%   V1.0.1 中 bump/droop 不参与求解，行程判据以 wheel/shock 为主。
%
% 单位约定:
%   载荷[N]，行程[mm]，使用率[%]

fig = figure('Name', 'Corner Loads & Travel', 'Color', 'w');
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

names = results.corners.names;
x = 1:numel(names);

% 1) 角点载荷
nexttile;
bar(x, [results.corners.FzStatic(:), results.corners.FzTotal(:)], 0.8);
set(gca, 'XTick', x, 'XTickLabel', names);
ylabel('Normal Load [N]');
title('Corner Loads');
legend({'Static', 'Total'}, 'Location', 'best');
grid on;

% 2) wheel travel
nexttile;
bar(x, [results.corners.wheelJounce(:), results.corners.wheelDroop(:)] * 1e3, 0.8);
set(gca, 'XTick', x, 'XTickLabel', names);
ylabel('Wheel Travel [mm]');
title('Wheel Jounce / Droop');
legend({'Jounce(+)', 'Droop(+)'}, 'Location', 'best');
grid on;

% 3) shock 使用率
nexttile;
bar(x, [results.corners.shockCompUsagePct(:), results.corners.shockReboundUsagePct(:)], 0.8);
hold on;
yline(100, 'r--', '100% limit', 'LineWidth', 1.0);
hold off;
set(gca, 'XTick', x, 'XTickLabel', names);
ylabel('Usage [%]');
title('Shock Stroke Usage');
legend({'Compression', 'Rebound'}, 'Location', 'best');
grid on;

% 4) shock margin
nexttile;
bar(x, [results.corners.shockCompMargin(:), results.corners.shockReboundMargin(:)] * 1e3, 0.8);
hold on;
yline(0, 'r--', '0 mm violation', 'LineWidth', 1.0);
hold off;
set(gca, 'XTick', x, 'XTickLabel', names);
ylabel('Margin [mm]');
title('Shock Compression / Rebound Margin');
legend({'Comp margin', 'Rebound margin'}, 'Location', 'best');
grid on;
end
