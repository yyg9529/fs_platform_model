function test_tire_results_fields_exist()
%TEST_TIRE_RESULTS_FIELDS_EXIST 启用轮胎代理层后 results.tire 字段完整。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

res = run_case(build_test_tire_proxy_case());

assert(isfield(res, 'tire'), 'Expected results.tire.');
assert(isfield(res.tire, 'inputs') && isfield(res.tire, 'forces') && isfield(res.tire, 'coeff'), ...
    'Expected inputs/forces/coeff sub-structures.');
assert(isfield(res.tire, 'balance') && isfield(res.tire, 'validity') && isfield(res.tire, 'scan'), ...
    'Expected balance/validity/scan sub-structures.');
assert(isfield(res.flags, 'tireEvalFailed') && isfield(res.flags, 'tireOutOfRange'), ...
    'Expected tire-related flags.');

fprintf('[PASS] test_tire_results_fields_exist\n');
end
