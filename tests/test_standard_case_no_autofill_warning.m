function test_standard_case_no_autofill_warning()
%TEST_STANDARD_CASE_NO_AUTOFILL_WARNING 标准 case 不应依赖 autofill warning 成立。
% 功能说明:
%   1) baseline / target case 的当前活跃字段应显式给出。
%   2) validate_case_struct 兼容机制仍保留，但标准 case 不应触发 autofill warning。
%   3) 在 warnOnDeprecatedInput=true 下运行 run_case 时，也不应发出接口清洁相关 warning。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

warnBacktrace = warning('query', 'backtrace');
cleanupObj = onCleanup(@() restore_warning_state(warnBacktrace));
warning('off', 'backtrace');

caseList = {build_case_2025_baseline(), build_case_2026_target()};
caseNames = {'build_case_2025_baseline', 'build_case_2026_target'};

for i = 1:numel(caseList)
    caseDef = caseList{i};
    [~, report] = validate_case_struct(caseDef);
    warnText = string(report.warnings);

    assert(isempty(report.filledForWarning), ...
        'Expected %s to have no reportable autofill fields.', caseNames{i});
    assert(~any(contains(warnText, "Auto-filled missing fields")), ...
        'Expected %s to avoid autofill warning.', caseNames{i});

    caseDef.solver.warnOnDeprecatedInput = true;
    lastwarn('');
    run_case(caseDef);
    [warnMsg, warnId] = lastwarn;
    assert(isempty(warnId) && isempty(warnMsg), ...
        'Expected %s to run without emitted validation warnings.', caseNames{i});
end

fprintf('[PASS] test_standard_case_no_autofill_warning\n');
end

function restore_warning_state(warnBacktrace)
warning(warnBacktrace.state, 'backtrace');
end
