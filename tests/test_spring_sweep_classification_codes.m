function test_spring_sweep_classification_codes()
%TEST_SPRING_SWEEP_CLASSIFICATION_CODES 验证四色分类编码、标签与颜色一致。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

classOut = classify_spring_sweep_map([false true false true], [false false true true]);
expectedCodes = [0 1 2 3];
expectedLabels = ["All Cases Fail"; "Only Aero Passes"; "Only Scrape Passes"; "Both Cases Pass"];

assert(isequal(classOut.classCode, expectedCodes), 'Expected class codes [0 1 2 3].');
assert(isequal(classOut.classLabel(:), expectedLabels), 'Expected class labels to match formal definitions.');
assert(all(size(classOut.palette) == [4 3]), 'Expected a 4x3 fixed color palette.');

fprintf('[PASS] test_spring_sweep_classification_codes\n');
end
