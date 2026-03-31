function test_shock_stroke_from_susp_wheel()
%TEST_SHOCK_STROKE_FROM_SUSP_WHEEL 验证 shockStroke 来源语义。
% 功能说明:
%   验证 V1.0.3 中 shockStroke 必须由 deltaSuspWheel 计算，
%   而不是由 deltaGround 计算。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 180000;
caseDef.tire.ktRear = 200000;
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

results = run_case(caseDef);

shockExpected = results.inputs.sus.mr(:) .* results.corners.deltaSuspWheel(:);
err = max(abs(results.corners.shockStroke(:) - shockExpected(:)));
assert(err < 1e-12, 'shockStroke is not consistent with mr .* deltaSuspWheel.');

% 在 fixed 模式下，deltaGround 通常不等于 deltaSuspWheel；
% 用它计算会产生偏差，确保实现没有走错语义。
wrongShock = results.inputs.sus.mr(:) .* results.corners.deltaGround(:);
if max(abs(results.corners.deltaTire)) > 1e-9
    diffWrong = max(abs(results.corners.shockStroke(:) - wrongShock(:)));
    assert(diffWrong > 1e-8, 'shockStroke appears to be computed from deltaGround, which is incorrect.');
end

fprintf('[PASS] test_shock_stroke_from_susp_wheel\n');
end
