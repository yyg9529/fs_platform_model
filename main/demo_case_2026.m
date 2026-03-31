function demo_case_2026()
%DEMO_CASE_2026 V1.0.4 示例脚本。
% 功能说明:
%   构建标准 2026 target case，调用 run_case，输出关键结果并绘图。
%   本 demo 走当前正式接口链：
%   1) 标准 case 已显式补齐活跃字段；
%   2) 轮胎输入正式归属 tire.*；
%   3) 正常运行时不应依赖 autofill / sus.kt deprecated warning。

thisFile = mfilename('fullpath');
mainDir = fileparts(thisFile);
rootDir = fileparts(mainDir);
addpath(genpath(rootDir));

caseDef = build_case_2026_target();
results = run_case(caseDef);

fprintf('=== Demo: %s ===\n', results.meta.name);
fprintf('Converged: %d\n', results.flags.converged);
fprintf('RulePass : %d\n', results.flags.rulePass);
fprintf('DesignPass: %d\n', results.flags.designPass);
fprintf('Feasible : %d\n', results.flags.feasible);
fprintf('AeroPlatformPass: %d\n', results.flags.aeroPlatformPass);
fprintf('ScrapePass (quasi / bump-adjusted): %d / %d\n', ...
    results.flags.scrapePassQuasiStatic, results.flags.scrapePassBumpAdjusted);
fprintf('Tire mode: %s (ktCase=%s)\n', results.tire.mode, results.tire.ktCaseLabel);
fprintf('z = %.4f mm\n', results.state.z * 1e3);
fprintf('theta = %.4f deg\n', results.state.theta_deg);
fprintf('phi = %.4f deg\n', results.state.phi_deg);
fprintf('hf/hr = %.2f / %.2f mm\n', results.aero.hf * 1e3, results.aero.hr * 1e3);
fprintf('Fz_aero = %.1f N, Drag = %.1f N\n', results.aero.Fz, results.aero.Drag);
fprintf('hStaticMin = %.2f mm @ %s\n', results.clearance.hStaticMin * 1e3, results.clearance.hStaticMinName);
fprintf('hDynamicMin = %.2f mm @ %s\n', results.clearance.hDynamicMin * 1e3, results.clearance.hDynamicMinName);
fprintf('hDynamicMinBumpAdjusted = %.2f mm @ %s\n', ...
    results.clearance.hDynamicMinBumpAdjusted * 1e3, results.clearance.hDynamicMinBumpAdjustedName);
fprintf('Effective jounce / droop / total travel = %.2f / %.2f / %.2f mm\n', ...
    results.rules.minEffectiveJounce * 1e3, ...
    results.rules.minEffectiveDroop * 1e3, ...
    results.rules.minEffectiveTotalTravel * 1e3);
fprintf('Travel violation any: %d\n', results.flags.travelViolationAny);
fprintf('  wheelJounce/wheelDroop = %d / %d\n', ...
    results.flags.wheelJounceViolationAny, results.flags.wheelDroopViolationAny);
fprintf('  shockComp/shockRebound = %d / %d\n', ...
    results.flags.shockCompViolationAny, results.flags.shockReboundViolationAny);
fprintf('Clearance violation (dynamic / bump-adjusted): %d / %d\n', ...
    results.flags.clearanceViolation, results.flags.bumpAdjustedClearanceViolation);
fprintf('Map classes (quasi / bump-adjusted): %d / %d\n', ...
    results.flags.mapClassQuasiStatic, results.flags.mapClassBumpAdjusted);
fprintf('Map clamped/fallback: %d / %d\n', results.flags.mapClampedAny, results.flags.interpFallbackUsed);

plot_pose_summary(results);
plot_corner_loads(results);
plot_clearance_map(results);
plot_aero_balance(results);
end
