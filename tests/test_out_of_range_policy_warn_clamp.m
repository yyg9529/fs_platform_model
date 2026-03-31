function test_out_of_range_policy_warn_clamp()
%TEST_OUT_OF_RANGE_POLICY_WARN_CLAMP 越界时正确 warning / clamp / 置位 flag。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

warnBacktrace = warning('query', 'backtrace');
cleanupObj = onCleanup(@() warning(warnBacktrace.state, 'backtrace')); %#ok<NASGU>
warning('off', 'backtrace');

caseDef = build_test_tire_proxy_case();
caseDef.tireOp.alpha = 30.0;
caseDef.tireOp.gamma = -8.0;
caseDef.tire.forceModel.outOfRangePolicy = 'warn_clamp';

lastwarn('');
res = run_case(caseDef);
[warnMsg, warnId] = lastwarn;

assert(strcmp(warnId, 'evaluate_tire_table_model:OutOfRange'), ...
    'Expected evaluate_tire_table_model:OutOfRange warning.');
assert(~isempty(warnMsg), 'Expected non-empty out-of-range warning message.');
assert(res.flags.tireOutOfRange, 'Expected tireOutOfRange flag when clamp occurs.');
assert(~res.flags.tireEvalFailed, 'Clamp policy should not fail tire evaluation.');
assert(all(isfinite(res.tire.forces.Fy)), 'Clamp policy should still return finite forces.');

fprintf('[PASS] test_out_of_range_policy_warn_clamp\n');
end
