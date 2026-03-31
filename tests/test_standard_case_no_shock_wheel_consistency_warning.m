function test_standard_case_no_shock_wheel_consistency_warning()
%TEST_STANDARD_CASE_NO_SHOCK_WHEEL_CONSISTENCY_WARNING 标准 case 不应长期带 shock/wheel 一致性 warning。
% 功能说明:
%   baseline / target 作为正式案例，应保证 shock 折算轮端容量与 jounce/droop 设定一致。
%   异常构造 case 的 warning 测试仍由 test_shock_wheel_consistency_warning 负责。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseList = {build_case_2025_baseline(), build_case_2026_target()};
caseNames = {'build_case_2025_baseline', 'build_case_2026_target'};

for i = 1:numel(caseList)
    caseDef = caseList{i};
    [~, report] = validate_case_struct(caseDef);
    assert(~report.shockWheelConsistencyWarning, ...
        'Expected %s not to trigger shock/wheel consistency warning in validation.', caseNames{i});

    results = run_case(caseDef);
    assert(~results.flags.shockWheelConsistencyWarning, ...
        'Expected %s not to carry shockWheelConsistencyWarning in results.', caseNames{i});
end

fprintf('[PASS] test_standard_case_no_shock_wheel_consistency_warning\n');
end
