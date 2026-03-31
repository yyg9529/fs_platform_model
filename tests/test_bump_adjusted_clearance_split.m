function test_bump_adjusted_clearance_split()
%TEST_BUMP_ADJUSTED_CLEARANCE_SPLIT 验证 bump-adjusted clearance 与原 dynamic clearance 分离。
% 功能说明:
%   1) hDynamicAllBumpAdjusted 按前后 reserve 正确扣减。
%   2) hDynamicAll / hDynamicMin 原值不被覆盖。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;
caseDef.bumpAdjust.enable = true;
caseDef.bumpAdjust.reserveFront = 0.004;
caseDef.bumpAdjust.reserveRear = 0.002;

res = run_case(caseDef);
reserveByPoint = zeros(size(caseDef.ref.xClear(:)));
reserveByPoint(caseDef.ref.xClear(:) > 0) = caseDef.bumpAdjust.reserveFront;
reserveByPoint(caseDef.ref.xClear(:) < 0) = caseDef.bumpAdjust.reserveRear;
reserveByPoint(caseDef.ref.xClear(:) == 0) = max(caseDef.bumpAdjust.reserveFront, caseDef.bumpAdjust.reserveRear);
expected = res.clearance.hDynamicAll - reserveByPoint;

assert(max(abs(res.clearance.hDynamicAllBumpAdjusted - expected)) < 1e-12, ...
    'Expected hDynamicAllBumpAdjusted to equal hDynamicAll minus reserveByPoint.');
assert(abs(res.clearance.hDynamicMin - min(res.clearance.hDynamicAll)) < 1e-12, ...
    'Expected original hDynamicMin to remain unchanged.');
assert(any(abs(res.clearance.hDynamicAllBumpAdjusted - res.clearance.hDynamicAll) > 1e-12), ...
    'Expected bump-adjusted clearance to differ from original dynamic clearance.');

fprintf('[PASS] test_bump_adjusted_clearance_split\n');
end
