function test_demo_case_no_interface_cleanup_warning()
%TEST_DEMO_CASE_NO_INTERFACE_CLEANUP_WARNING 正式 demo 不应依赖接口清洁 warning 才成立。
% 功能说明:
%   1) demo_case_2026 应沿用清洁后的标准 target case 输入链。
%   2) 正常运行时不应出现 autofill 或 sus.kt deprecated warning。
%   3) 本测试只检查正式 demo，不替代异常 warning 覆盖测试。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

warnBacktrace = warning('query', 'backtrace');
figVisible = get(0, 'DefaultFigureVisible');
cleanupObj = onCleanup(@() restore_demo_state(warnBacktrace, figVisible));
warning('off', 'backtrace');
set(0, 'DefaultFigureVisible', 'off');
close all force;

lastwarn('');
evalc('demo_case_2026;');
[warnMsg, warnId] = lastwarn;
assert(isempty(warnId) && isempty(warnMsg), ...
    'Expected demo_case_2026 to run without interface cleanup warnings.');

fprintf('[PASS] test_demo_case_no_interface_cleanup_warning\n');
end

function restore_demo_state(warnBacktrace, figVisible)
close all force;
warning(warnBacktrace.state, 'backtrace');
set(0, 'DefaultFigureVisible', figVisible);
end
