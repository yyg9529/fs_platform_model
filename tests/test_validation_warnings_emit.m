function test_validation_warnings_emit()
%TEST_VALIDATION_WARNINGS_EMIT validation.warnings 发射测试。
% 功能说明:
%   验证 warnOnDeprecatedInput=true 时，run_case 会把 validation.warnings
%   真实转成 warning(...)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

warnBacktrace = warning('query', 'backtrace');
warnDelta = warning('query', 'postprocess_results:DeltaReconMismatch');
cleanupObj = onCleanup(@() restore_warning_state(warnBacktrace, warnDelta));
warning('off', 'backtrace');
warning('off', 'postprocess_results:DeltaReconMismatch');

caseDef = build_case_2026_target();
caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;
caseDef.solver.warnOnDeprecatedInput = true;
caseDef.sus.kBump = 1000;

lastwarn('');
run_case(caseDef);
[warnMsgOn, warnIdOn] = lastwarn;
assert(strcmp(warnIdOn, 'run_case:ValidationWarning'), ...
    'Expected run_case:ValidationWarning when warnOnDeprecatedInput=true.');
assert(~isempty(warnMsgOn), 'Expected non-empty validation warning message.');

caseDef.solver.warnOnDeprecatedInput = false;
lastwarn('');
run_case(caseDef);
[~, warnIdOff] = lastwarn;
assert(isempty(warnIdOff), 'Expected no validation warning when warnOnDeprecatedInput=false.');

fprintf('[PASS] test_validation_warnings_emit\n');
end

function restore_warning_state(warnBacktrace, warnDelta)
warning(warnBacktrace.state, 'backtrace');
warning(warnDelta.state, 'postprocess_results:DeltaReconMismatch');
end
