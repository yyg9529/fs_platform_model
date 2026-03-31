function fig = plot_aero_balance(results)
%PLOT_AERO_BALANCE Plot aero total load and balance indicators.
% 输入:
%   results - run_case 输出结构体

fig = figure('Name', 'Aero Balance', 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar([results.aero.FzFront, results.aero.FzRear]);
set(gca, 'XTickLabel', {'Front Aero Fz', 'Rear Aero Fz'});
ylabel('Load [N]');
title('Aero Axle Loads');
grid on;

nexttile;
yyaxis left;
bar(1, results.aero.frontShare * 100, 0.45);
ylabel('Front Share [%]');
ylim([0, 100]);
yyaxis right;
plot(1, results.aero.lossPct, 'ko', 'MarkerFaceColor', 'k');
ylabel('Aero Loss [%]');
xlim([0.5, 1.5]);
set(gca, 'XTick', 1, 'XTickLabel', {'Balance / Loss'});
title('Aero Balance Drift');
grid on;
end
