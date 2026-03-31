function fig = plot_pose_summary(results)
%PLOT_POSE_SUMMARY 姿态与关键标志汇总图。
% 功能说明:
%   快速显示 z/theta/phi、clearance 与 V1.0.4 的核心筛选标志。
%
% 输入:
%   results - run_case 输出结构体
%
% 输出:
%   fig - 图窗句柄
%
% 单位约定:
%   z[mm], theta/phi[deg]

fig = figure('Name', 'Pose Summary', 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
vals = [results.state.z * 1e3, results.state.theta_deg, results.state.phi_deg];
bar(vals, 0.6);
set(gca, 'XTickLabel', {'z [mm]', 'theta [deg]', 'phi [deg]'});
ylabel('Value');
title('Platform Pose');
grid on;

nexttile;
text(0.0, 0.88, sprintf('Converged: %d', results.flags.converged), 'FontSize', 10);
text(0.0, 0.76, sprintf('Aero/scrape(qs/bump): %d / %d / %d', ...
    results.flags.aeroPlatformPass, ...
    results.flags.scrapePassQuasiStatic, ...
    results.flags.scrapePassBumpAdjusted), 'FontSize', 10);
text(0.0, 0.64, sprintf('hf/hr: %.1f / %.1f mm', results.aero.hf*1e3, results.aero.hr*1e3), 'FontSize', 10);
text(0.0, 0.52, sprintf('Roll/Pitch grad: %.2f / %.2f deg/g', ...
    results.metrics.rollGradient_deg_per_g, results.metrics.pitchGradient_deg_per_g), 'FontSize', 10);
text(0.0, 0.40, sprintf('hStatic/hDyn/hDynBump: %.1f / %.1f / %.1f mm', ...
    results.platform.hStaticMin*1e3, ...
    results.platform.hDynamicMin*1e3, ...
    results.platform.hDynamicMinBumpAdjusted*1e3), 'FontSize', 10);
text(0.0, 0.28, sprintf('Eff jounce/droop/total: %.1f / %.1f / %.1f mm', ...
    results.rules.minEffectiveJounce*1e3, ...
    results.rules.minEffectiveDroop*1e3, ...
    results.rules.minEffectiveTotalTravel*1e3), 'FontSize', 10);
text(0.0, 0.16, sprintf('Map class (qs/bump): %d / %d', ...
    results.flags.mapClassQuasiStatic, results.flags.mapClassBumpAdjusted), 'FontSize', 10);
text(0.0, 0.04, sprintf('Travel/clearance/bumpViolation: %d / %d / %d', ...
    results.flags.travelViolationAny, ...
    results.flags.clearanceViolation, ...
    results.flags.bumpAdjustedClearanceViolation), 'FontSize', 10);
axis off;
title('Key Indicators');
end
