function test_delta_decomposition_consistency()
%TEST_DELTA_DECOMPOSITION_CONSISTENCY 位移分解一致性测试。
% 功能说明:
%   验证 V1.0.3 中：
%   deltaGround = deltaSuspWheel + deltaTire，且重构误差在容差内。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 210000;
caseDef.tire.ktRear = 230000;
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

results = run_case(caseDef);

lhs = results.corners.deltaGround(:);
rhs = results.corners.deltaSuspWheel(:) + results.corners.deltaTire(:);
err = max(abs(lhs - rhs));
assert(err < 1e-12, 'delta decomposition identity failed.');

reconErr = max(abs(results.debug.validation.deltaReconError(:)));
assert(reconErr < 1e-8, 'delta reconstruction error exceeds tolerance.');

fprintf('[PASS] test_delta_decomposition_consistency\n');
end
