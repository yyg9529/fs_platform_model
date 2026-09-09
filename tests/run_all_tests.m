function summary = run_all_tests()
%RUN_ALL_TESTS Run discoverable contracts and legacy regression functions.
% This is the project test entry point. It fails if the discoverable suite
% is empty or if any legacy test_*.m function throws.

testDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testDir);
oldPath = path;
cleanup = onCleanup(@() path(oldPath));
addpath(genpath(projectRoot));

expectedClassFiles = { ...
    'TestAeroAndClassificationValidity.m'; ...
    'TestPhysicalLoadClosure.m'; ...
    'TestSolverAndSweepContracts.m'; ...
    'TestTireContracts.m'};
for i = 1:numel(expectedClassFiles)
    if ~isfile(fullfile(testDir, expectedClassFiles{i}))
        error('run_all_tests:MissingTestClass', ...
            'Expected discoverable test class is missing: %s', expectedClassFiles{i});
    end
end

suite = matlab.unittest.TestSuite.fromFolder(testDir);
if isempty(suite)
    error('run_all_tests:NoDiscoverableTests', ...
        'No matlab.unittest tests were discovered in %s.', testDir);
end
if numel(suite) < 39
    error('run_all_tests:DiscoverableInventoryReduced', ...
        'Expected at least 39 discoverable tests, but found %d.', numel(suite));
end
frameworkResults = run(suite);
if any([frameworkResults.Failed]) || any([frameworkResults.Incomplete])
    error('run_all_tests:FrameworkFailure', ...
        '%d discoverable tests failed or were incomplete.', ...
        sum([frameworkResults.Failed] | [frameworkResults.Incomplete]));
end

legacyFiles = dir(fullfile(testDir, 'test_*.m'));
if numel(legacyFiles) ~= 56
    error('run_all_tests:LegacyInventoryChanged', ...
        'Expected 56 legacy regression entry points, but found %d.', numel(legacyFiles));
end
legacyNames = strings(numel(legacyFiles), 1);
legacyPassed = false(numel(legacyFiles), 1);
legacyMessages = strings(numel(legacyFiles), 1);
for i = 1:numel(legacyFiles)
    [~, functionName] = fileparts(legacyFiles(i).name);
    legacyNames(i) = string(functionName);
    try
        feval(functionName);
        legacyPassed(i) = true;
    catch ME
        legacyMessages(i) = string(getReport(ME, 'basic', 'hyperlinks', 'off'));
    end
end
if any(~legacyPassed)
    failedNames = strjoin(cellstr(legacyNames(~legacyPassed)), ', ');
    error('run_all_tests:LegacyFailure', ...
        'Legacy regression failures: %s', failedNames);
end

summary = struct();
summary.frameworkResults = frameworkResults;
summary.nFramework = numel(frameworkResults);
summary.nFrameworkPassed = sum([frameworkResults.Passed]);
summary.legacy = table(legacyNames, legacyPassed, legacyMessages, ...
    'VariableNames', {'Name', 'Passed', 'Message'});
summary.nLegacy = numel(legacyFiles);
summary.nLegacyPassed = sum(legacyPassed);
end
