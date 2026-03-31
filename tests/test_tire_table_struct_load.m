function test_tire_table_struct_load()
%TEST_TIRE_TABLE_STRUCT_LOAD 验证 table_struct 能正确装配并归一化。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_test_tire_proxy_case();
tireData = load_tire_table_data(caseDef);

assert(tireData.summary.hasFy && tireData.summary.hasFx && tireData.summary.hasMz, ...
    'Expected Fy/Fx/Mz tables to be available.');
assert(max(abs(tireData.tables.Fy.rawTable.alpha)) < pi, 'Expected alpha to be normalized into rad.');
assert(max(abs(tireData.tables.Fy.rawTable.gamma)) < pi, 'Expected gamma to be normalized into rad.');
assert(all(isfinite(tireData.tables.Fx.rawTable.Fx)), 'Expected finite normalized Fx values.');
assert(~isempty(tireData.capability.FyAbs) && ~isempty(tireData.capability.FxAbs), ...
    'Expected capability helper models to be available.');

fprintf('[PASS] test_tire_table_struct_load\n');
end
