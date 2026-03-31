function test_tire_mode_off_fixed_range()
%TEST_TIRE_MODE_OFF_FIXED_RANGE 轮胎柔度模式开关测试。
% 功能说明:
%   验证 off/fixed/range 三种模式都可运行，且输出语义正确。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

baseCase = build_case_2026_target();
baseCase.rules.enforceRules = false;
baseCase.targets.enforceTargets = false;

% ===== off =====
caseOff = baseCase;
caseOff.tire.mode = 'off';
resOff = run_case(caseOff);
assert(strcmpi(resOff.tire.mode, 'off'), 'Expected tire.mode=off output.');
assert(resOff.flags.tireComplianceIgnored, 'Expected tireComplianceIgnored=true in off mode.');
assert(max(abs(resOff.corners.deltaTire)) < 1e-12, 'Expected deltaTire=0 in off mode.');

% ===== fixed =====
caseFix = baseCase;
caseFix.tire.mode = 'fixed';
caseFix.tire.ktFront = 210000;
caseFix.tire.ktRear = 230000;
resFix = run_case(caseFix);
assert(strcmpi(resFix.tire.mode, 'fixed'), 'Expected tire.mode=fixed output.');
assert(~resFix.flags.tireComplianceIgnored, 'Expected tireComplianceIgnored=false in fixed mode.');
assert(max(abs(resFix.corners.deltaTire)) > 1e-8, 'Expected non-zero deltaTire in fixed mode.');
assert(all(resFix.inputs.derived.stiff.keq < resFix.inputs.derived.stiff.kw), ...
    'Expected keq < kw in fixed mode due to series stiffness.');

% ===== range =====
caseRng = baseCase;
caseRng.tire.mode = 'range';
caseRng.tire.ktFrontRange = [180000 210000 240000];
caseRng.tire.ktRearRange = [200000 230000 260000];
resRng = run_case(caseRng);
assert(strcmpi(resRng.tire.mode, 'range'), 'Expected tire.mode=range output.');
assert(isfield(resRng, 'range') && isfield(resRng.range, 'low') && isfield(resRng.range, 'nominal') && isfield(resRng.range, 'high'), ...
    'Expected range.low/nominal/high outputs.');

hVec = [resRng.range.low.clearance.hMin, resRng.range.nominal.clearance.hMin, resRng.range.high.clearance.hMin];
assert(max(abs(hVec - hVec(2))) > 1e-10, 'Expected range scenarios to produce non-identical hMin values.');

fprintf('[PASS] test_tire_mode_off_fixed_range\n');
end
