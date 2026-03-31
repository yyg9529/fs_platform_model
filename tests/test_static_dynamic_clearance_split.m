function test_static_dynamic_clearance_split()
%TEST_STATIC_DYNAMIC_CLEARANCE_SPLIT 静态/动态离地高语义拆分测试。
% 功能说明:
%   验证：
%   1) 静态离地高直接等于 ref.hClear0
%   2) 动态离地高来自当前 q
%   3) 兼容字段 hMin 仍指向动态最小离地高

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;
caseDef.man.V = 35.0;
caseDef.man.ax = -4.0;
caseDef.man.ay = 11.0;

res = run_case(caseDef);

tol = 1e-12;
assert(max(abs(res.clearance.hStaticAll - caseDef.ref.hClear0(:))) < tol, ...
    'Expected static clearance to equal ref.hClear0.');
assert(max(abs(res.clearance.hDynamicAll - res.platform.clearanceDynamicValues(:))) < tol, ...
    'Expected dynamic clearance to match platform dynamic values.');
assert(abs(res.clearance.hMin - res.clearance.hDynamicMin) < tol, ...
    'Expected compatibility field hMin to map to hDynamicMin.');
assert(res.clearance.hDynamicMin < res.clearance.hStaticMin - 1e-6, ...
    'Expected loaded dynamic clearance to be lower than static clearance.');

fprintf('[PASS] test_static_dynamic_clearance_split\n');
end
