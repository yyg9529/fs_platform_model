function fig = plot_clearance_map(results)
%PLOT_CLEARANCE_MAP 绘制关键检查点的静态/动态/bump-adjusted 离地高对比。
% 功能说明:
%   同时展示 static clearance、dynamic clearance 以及 bump-adjusted dynamic clearance。
%
% 输入:
%   results - run_case 输出结构体
%
% 输出:
%   fig - 图窗句柄
%
% 关键物理假设:
%   bump-adjusted clearance 仅是对 dynamic clearance 的保守扣减，不是瞬态求解结果。
%
% 单位约定:
%   图中显示单位为 mm

fig = figure('Name', 'Clearance Map', 'Color', 'w');
vals = [ ...
    results.platform.clearanceStaticValues(:), ...
    results.platform.clearanceDynamicValues(:), ...
    results.platform.clearanceBumpAdjustedValues(:)] * 1e3; % mm
names = results.platform.clearanceNames(:);

bar(vals, 'grouped');
hold on;
yline(0, 'r--', '0 mm limit', 'LineWidth', 1.1);
hold off;
set(gca, 'XTick', 1:numel(names), 'XTickLabel', names);
ylabel('Clearance [mm]');
title('Static vs Dynamic vs Bump-Adjusted Clearance');
legend({'Static', 'Dynamic', 'Bump-Adjusted'}, 'Location', 'best');
grid on;
xtickangle(20);
end
