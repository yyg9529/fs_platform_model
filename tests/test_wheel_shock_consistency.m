function test_wheel_shock_consistency()
%TEST_WHEEL_SHOCK_CONSISTENCY wheel/shock 关系一致性测试。
% 功能说明:
%   验证核心关系：shockStroke = mr .* deltaSuspWheel。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

results = run_case(caseDef);

expectedShockStroke = results.inputs.sus.mr(:) .* results.corners.deltaSuspWheel(:);
err = max(abs(results.corners.shockStroke(:) - expectedShockStroke(:)));
assert(err < 1e-12, 'shockStroke is not consistent with mr .* deltaSuspWheel.');

fprintf('[PASS] test_wheel_shock_consistency\n');
end
