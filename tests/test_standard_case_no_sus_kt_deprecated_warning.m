function test_standard_case_no_sus_kt_deprecated_warning()
%TEST_STANDARD_CASE_NO_SUS_KT_DEPRECATED_WARNING 标准 case 不应正式使用 sus.kt。
% 功能说明:
%   1) 当前正式轮胎输入语义归属 tire.*。
%   2) sus.kt 仅保留旧 case 兼容路径，不应继续出现在 baseline / target 正式输入中。
%   3) validate_case_struct 不应对标准 case 发出 sus.kt deprecated warning。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseList = {build_case_2025_baseline(), build_case_2026_target()};
caseNames = {'build_case_2025_baseline', 'build_case_2026_target'};

for i = 1:numel(caseList)
    caseDef = caseList{i};
    if isfield(caseDef.sus, 'kt')
        assert(isempty(caseDef.sus.kt), ...
            'Expected %s not to use non-empty sus.kt as formal input.', caseNames{i});
    end

    [~, report] = validate_case_struct(caseDef);
    warnText = string(report.warnings);
    assert(~any(contains(warnText, "caseDef.sus.kt is deprecated")), ...
        'Expected %s not to trigger sus.kt deprecated warning.', caseNames{i});

    assert(strcmpi(caseDef.tire.mode, 'off') || strcmpi(caseDef.tire.mode, 'fixed') || strcmpi(caseDef.tire.mode, 'range'), ...
        'Expected %s to use current tire.mode interface.', caseNames{i});
end

fprintf('[PASS] test_standard_case_no_sus_kt_deprecated_warning\n');
end
