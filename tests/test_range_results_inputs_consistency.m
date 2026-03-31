function test_range_results_inputs_consistency()
%TEST_RANGE_RESULTS_INPUTS_CONSISTENCY range 模式 inputs 结构一致性测试。
% 功能说明:
%   验证顶层 results.inputs 保持 primary 场景的预处理结构，
%   同时保留 inputsRaw 和 inputsNominal。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2026_target();
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;
caseDef.tire.mode = 'range';
caseDef.tire.ktFrontRange = [190000, 220000, 250000];
caseDef.tire.ktRearRange = [210000, 240000, 270000];

res = run_case(caseDef);

assert(isfield(res, 'inputsRaw') && isfield(res, 'inputsNominal'), ...
    'Expected results.inputsRaw and results.inputsNominal in range mode.');
assert(strcmpi(res.inputsRaw.tire.mode, 'range'), 'Expected inputsRaw to preserve range mode.');
assert(~isfield(res.inputsRaw, 'derived'), 'Expected inputsRaw to remain non-preprocessed.');
assert(isfield(res.inputs, 'derived'), 'Expected top-level inputs to remain preprocessed primary scenario.');
assert(strcmpi(res.inputs.tire.mode, 'fixed'), 'Expected primary inputs to be fixed single-kt scenario.');
assert(isfield(res.inputsNominal, 'derived'), 'Expected inputsNominal to be preprocessed.');
assert(strcmpi(res.inputsNominal.tire.mode, 'fixed'), 'Expected inputsNominal tire.mode=fixed.');
assert(all(abs(res.inputs.derived.stiff.keq - res.range.nominal.inputs.derived.stiff.keq) < 1e-12), ...
    'Expected primary top-level inputs to remain aligned with nominal scenario.');
assert(isfield(res.range, 'band') && numel(res.range.band.hStaticMin) == 3, ...
    'Expected range.band to expose 3-point bands for static/dynamic outputs.');

fprintf('[PASS] test_range_results_inputs_consistency\n');
end
