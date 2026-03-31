function test_tire_excel_load()
%TEST_TIRE_EXCEL_LOAD 验证 excel_file 能正确读取指定 sheet / 列名。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

tmpFile = fullfile(tempdir, 'fs_platform_model_v15_tire_demo.xlsx');
cleanupObj = onCleanup(@() cleanup_temp_file(tmpFile)); %#ok<NASGU>

demoData = build_demo_tire_force_tables();
writetable(demoData.FyTable, tmpFile, 'Sheet', 'FyTable');
writetable(demoData.MzTable, tmpFile, 'Sheet', 'MzTable');
writetable(demoData.FxTable, tmpFile, 'Sheet', 'FxTable');
writetable(struct2table(demoData.Meta), tmpFile, 'Sheet', 'Meta');

caseDef = build_test_tire_proxy_case();
caseDef.tire.forceModel.sourceType = 'excel_file';
caseDef.tire.forceModel.file = tmpFile;
caseDef.tire.forceModel.data = struct();

tireData = load_tire_table_data(caseDef);
assert(tireData.summary.hasFy && tireData.summary.hasFx && tireData.summary.hasMz, ...
    'Expected Excel tire file to load Fy/Fx/Mz sheets.');
assert(strcmpi(tireData.sourceType, 'excel_file'), 'Expected sourceType=excel_file.');

fprintf('[PASS] test_tire_excel_load\n');
end

function cleanup_temp_file(filePath)
if exist(filePath, 'file')
    delete(filePath);
end
end
