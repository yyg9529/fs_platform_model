function tireTableData = load_tire_table_data(caseDef)
%LOAD_TIRE_TABLE_DATA 统一读取并归一化 V1.5 轮胎代理层表格数据。
% 功能说明:
%   1) 支持 table_struct 与 excel_file 两种首版正式数据源。
%   2) 完成列名检查、单位归一化，并构建统一插值模型。
%   3) 为未来 tir_file / function_handle 扩展保留 sourceType 入口。
%
% 输入:
%   caseDef - 通过 validate_case_struct 的输入结构，使用：
%             caseDef.tire.forceModel.*
%
% 输出:
%   tireTableData - 统一轮胎表结构，至少包含：
%                   .sourceType
%                   .meta
%                   .summary
%                   .tables.Fy / .tables.Fx / .tables.Mz
%                   .capability
%
% 关键物理假设:
%   1) 当前 V1.5 仍是平台求解后的轮胎后评估层。
%   2) 首版优先服务 Excel/表格代理层，不在此处引入 .tir 闭环求解。
%   3) 所有表格数据在进入 evaluator 前统一转为 SI。
%
% 单位约定:
%   alpha/gamma [rad]，kappa [-]，Fz/Fx/Fy [N]，Mz [N*m]，pressure [Pa]

forceModel = caseDef.tire.forceModel;
sourceType = lower(strtrim(char(string(forceModel.sourceType))));

switch sourceType
    case 'table_struct'
        rawData = local_load_from_table_struct(forceModel.data);
        sourceFile = '';

    case 'excel_file'
        sourceFile = local_resolve_input_path(forceModel.file);
        rawData = local_load_from_excel(sourceFile);

    case 'csv_longform'
        error('load_tire_table_data:CsvReserved', ...
            ['sourceType=csv_longform is reserved in V1.5 interface design, ', ...
            'but this first implementation focuses on table_struct/excel_file.']);

    case 'tir_file'
        error('load_tire_table_data:TirReserved', ...
            ['sourceType=tir_file is reserved for future V2.0 Magic Formula adapter. ', ...
            'V1.5 first release does not include a generic .tir parser.']);

    case 'function_handle'
        error('load_tire_table_data:FunctionReserved', ...
            ['sourceType=function_handle is reserved for future adapter work. ', ...
            'V1.5 first release keeps the interface but does not execute custom evaluators.']);

    otherwise
        error('load_tire_table_data:BadSourceType', 'Unsupported tire.forceModel.sourceType: %s', sourceType);
end

meta = local_normalize_meta(rawData, forceModel);

fyModel = [];
fxModel = [];
mzModel = [];
combinedModel = [];

if isfield(rawData, 'FyTable') && ~isempty(rawData.FyTable)
    fyModel = local_build_scalar_table_model(rawData.FyTable, {'alpha', 'Fz', 'gamma'}, 'Fy', meta, 'FyTable');
end
if isfield(rawData, 'FxTable') && ~isempty(rawData.FxTable)
    fxModel = local_build_scalar_table_model(rawData.FxTable, {'kappa', 'Fz', 'gamma'}, 'Fx', meta, 'FxTable');
end
if isfield(rawData, 'MzTable') && ~isempty(rawData.MzTable)
    mzModel = local_build_scalar_table_model(rawData.MzTable, {'alpha', 'Fz', 'gamma'}, 'Mz', meta, 'MzTable');
end
if isfield(rawData, 'CombinedTable') && ~isempty(rawData.CombinedTable)
    combinedModel = local_build_combined_model(rawData.CombinedTable, meta);
end

tireTableData = struct();
tireTableData.sourceType = sourceType;
tireTableData.sourceFile = sourceFile;
tireTableData.meta = meta;
tireTableData.tables = struct();
tireTableData.tables.Fy = fyModel;
tireTableData.tables.Fx = fxModel;
tireTableData.tables.Mz = mzModel;
tireTableData.tables.Combined = combinedModel;
tireTableData.capability = local_build_capability_models(fyModel, fxModel);
tireTableData.summary = struct();
tireTableData.summary.hasFy = ~isempty(fyModel);
tireTableData.summary.hasFx = ~isempty(fxModel);
tireTableData.summary.hasMz = ~isempty(mzModel);
tireTableData.summary.hasCombined = ~isempty(combinedModel);
tireTableData.summary.nFyRows = local_model_nrows(fyModel);
tireTableData.summary.nFxRows = local_model_nrows(fxModel);
tireTableData.summary.nMzRows = local_model_nrows(mzModel);
tireTableData.summary.nCombinedRows = local_model_nrows(combinedModel);
tireTableData.summary.label = sprintf('Fy=%d Fx=%d Mz=%d Combined=%d', ...
    tireTableData.summary.nFyRows, tireTableData.summary.nFxRows, ...
    tireTableData.summary.nMzRows, tireTableData.summary.nCombinedRows);
end

function rawData = local_load_from_table_struct(dataIn)
%LOCAL_LOAD_FROM_TABLE_STRUCT 直接接收 table_struct 输入。
if isempty(dataIn) || ~isstruct(dataIn)
    error('load_tire_table_data:MissingTableStruct', ...
        'For sourceType=table_struct, tire.forceModel.data must be a non-empty struct.');
end
rawData = dataIn;
end

function rawData = local_load_from_excel(filePath)
%LOCAL_LOAD_FROM_EXCEL 按约定 sheet 名读取 Excel 长表。
if isempty(filePath)
    error('load_tire_table_data:MissingExcelFile', ...
        'tire.forceModel.file must be provided when sourceType=excel_file.');
end
if ~exist(filePath, 'file')
    error('load_tire_table_data:ExcelFileNotFound', 'Excel file not found: %s', filePath);
end

sheets = sheetnames(filePath);
sheetSet = lower(string(sheets));

rawData = struct();
rawData.FyTable = local_read_excel_sheet_if_present(filePath, sheetSet, 'FyTable');
rawData.MzTable = local_read_excel_sheet_if_present(filePath, sheetSet, 'MzTable');
rawData.FxTable = local_read_excel_sheet_if_present(filePath, sheetSet, 'FxTable');
rawData.CombinedTable = local_read_excel_sheet_if_present(filePath, sheetSet, 'CombinedTable');
rawData.Meta = local_read_excel_meta_if_present(filePath, sheetSet);
end

function T = local_read_excel_sheet_if_present(filePath, sheetSet, sheetName)
%LOCAL_READ_EXCEL_SHEET_IF_PRESENT 读取指定 sheet；不存在则返回 []。
if ~any(sheetSet == lower(string(sheetName)))
    T = [];
    return;
end

T = readtable(filePath, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
end

function meta = local_read_excel_meta_if_present(filePath, sheetSet)
%LOCAL_READ_EXCEL_META_IF_PRESENT 读取 Meta sheet；不存在则返回 struct()。
if ~any(sheetSet == "meta")
    meta = struct();
    return;
end

metaTable = readtable(filePath, 'Sheet', 'Meta', 'VariableNamingRule', 'preserve');
meta = local_parse_meta(metaTable);
end

function meta = local_normalize_meta(rawData, forceModel)
%LOCAL_NORMALIZE_META 将 Meta 与 forceModel 显式单位统一成结构体。
meta = struct();
if isfield(rawData, 'Meta') && ~isempty(rawData.Meta)
    meta = local_parse_meta(rawData.Meta);
end

meta = local_merge_meta_default(meta, 'alphaUnit', forceModel.alphaUnit);
meta = local_merge_meta_default(meta, 'gammaUnit', forceModel.gammaUnit);
meta = local_merge_meta_default(meta, 'kappaUnit', forceModel.kappaUnit);
meta = local_merge_meta_default(meta, 'FzUnit', local_get_with_default(forceModel, 'FzUnit', 'N'));
meta = local_merge_meta_default(meta, 'forceUnit', local_get_with_default(forceModel, 'forceUnit', 'N'));
meta = local_merge_meta_default(meta, 'momentUnit', local_get_with_default(forceModel, 'momentUnit', 'N*m'));
meta = local_merge_meta_default(meta, 'pressureUnit', local_get_with_default(forceModel, 'pressureUnit', 'Pa'));
meta = local_merge_meta_default(meta, 'pressure', []);

meta.alphaUnit = local_normalize_unit_string(meta.alphaUnit);
meta.gammaUnit = local_normalize_unit_string(meta.gammaUnit);
meta.kappaUnit = local_normalize_unit_string(meta.kappaUnit);
meta.FzUnit = local_normalize_unit_string(meta.FzUnit);
meta.forceUnit = local_normalize_unit_string(meta.forceUnit);
meta.momentUnit = local_normalize_unit_string(meta.momentUnit);
meta.pressureUnit = local_normalize_unit_string(meta.pressureUnit);
end

function model = local_build_scalar_table_model(tableIn, inputNames, outputName, meta, label)
%LOCAL_BUILD_SCALAR_TABLE_MODEL 归一化 3 自变量长表并构建插值器。
T = local_as_table(tableIn, label);
local_require_columns(T, [inputNames, {outputName}], label);

x1 = local_convert_input_column(T.(inputNames{1}), inputNames{1}, meta);
x2 = local_convert_input_column(T.(inputNames{2}), inputNames{2}, meta);
x3 = local_convert_input_column(T.(inputNames{3}), inputNames{3}, meta);
y = local_convert_output_column(T.(outputName), outputName, meta);

if numel(y) < 8
    error('load_tire_table_data:InsufficientPoints', '%s does not contain enough points for interpolation.', label);
end
if any(~isfinite(x1)) || any(~isfinite(x2)) || any(~isfinite(x3)) || any(~isfinite(y))
    error('load_tire_table_data:NonFiniteData', '%s contains non-finite values.', label);
end

model = local_build_nd_model({x1, x2, x3}, y, inputNames, outputName, label);
model.rawTable = table(x1, x2, x3, y, 'VariableNames', [inputNames, {outputName}]);
end

function model = local_build_combined_model(tableIn, meta)
%LOCAL_BUILD_COMBINED_MODEL 读取可选 CombinedTable。
T = local_as_table(tableIn, 'CombinedTable');
required = {'alpha', 'kappa', 'Fz', 'gamma', 'Fx', 'Fy'};
local_require_columns(T, required, 'CombinedTable');

alpha = local_convert_input_column(T.alpha, 'alpha', meta);
kappa = local_convert_input_column(T.kappa, 'kappa', meta);
Fz = local_convert_input_column(T.Fz, 'Fz', meta);
gamma = local_convert_input_column(T.gamma, 'gamma', meta);
Fx = local_convert_output_column(T.Fx, 'Fx', meta);
Fy = local_convert_output_column(T.Fy, 'Fy', meta);
if ismember('Mz', T.Properties.VariableNames)
    Mz = local_convert_output_column(T.Mz, 'Mz', meta);
else
    Mz = nan(size(Fx));
end

if any(~isfinite(alpha)) || any(~isfinite(kappa)) || any(~isfinite(Fz)) || any(~isfinite(gamma))
    error('load_tire_table_data:CombinedNonFinite', 'CombinedTable contains non-finite inputs.');
end
if numel(Fx) < 16
    error('load_tire_table_data:CombinedInsufficientPoints', 'CombinedTable does not contain enough points.');
end

model = struct();
model.kind = 'combined';
model.inputNames = {'alpha', 'kappa', 'Fz', 'gamma'};
model.outputNames = {'Fx', 'Fy', 'Mz'};
model.minValues = [min(alpha), min(kappa), min(Fz), min(gamma)];
model.maxValues = [max(alpha), max(kappa), max(Fz), max(gamma)];
model.axes = {unique(sort(alpha)), unique(sort(kappa)), unique(sort(Fz)), unique(sort(gamma))};
model.interpolantFx = local_build_4d_interpolant(alpha, kappa, Fz, gamma, Fx, 'CombinedTable.Fx');
model.interpolantFy = local_build_4d_interpolant(alpha, kappa, Fz, gamma, Fy, 'CombinedTable.Fy');
if all(isfinite(Mz))
    model.interpolantMz = local_build_4d_interpolant(alpha, kappa, Fz, gamma, Mz, 'CombinedTable.Mz');
else
model.interpolantMz = [];
end
model.nRows = height(T);
model.rawTable = table(alpha, kappa, Fz, gamma, Fx, Fy, Mz, ...
    'VariableNames', {'alpha', 'kappa', 'Fz', 'gamma', 'Fx', 'Fy', 'Mz'});
end

function capability = local_build_capability_models(fyModel, fxModel)
%LOCAL_BUILD_CAPABILITY_MODELS 从纯表中构造峰值能力代理。
capability = struct();
capability.FyAbs = [];
capability.FxAbs = [];
capability.FxBrake = [];
capability.FxTraction = [];

if ~isempty(fyModel)
    capability.FyAbs = local_build_capability_model_from_table( ...
        fyModel.rawTable, 'Fz', 'gamma', 'Fy', 'abs');
end
if ~isempty(fxModel)
    capability.FxAbs = local_build_capability_model_from_table( ...
        fxModel.rawTable, 'Fz', 'gamma', 'Fx', 'abs');
    capability.FxBrake = local_build_capability_model_from_table( ...
        fxModel.rawTable, 'Fz', 'gamma', 'Fx', 'brake');
    capability.FxTraction = local_build_capability_model_from_table( ...
        fxModel.rawTable, 'Fz', 'gamma', 'Fx', 'traction');
end
end

function capModel = local_build_capability_model_from_table(T, FzField, gammaField, valueField, modeTag)
%LOCAL_BUILD_CAPABILITY_MODEL_FROM_TABLE 对每个 (Fz,gamma) 求峰值能力。
FzRaw = T.(FzField);
gammaRaw = T.(gammaField);
valRaw = T.(valueField);

Fz = double(FzRaw(:));
gamma = double(gammaRaw(:));
value = double(valRaw(:));

[FzAxis, ~, idxFz] = unique(Fz);
[gammaAxis, ~, idxGamma] = unique(gamma);

switch lower(modeTag)
    case 'abs'
        sample = abs(value);
    case 'brake'
        sample = zeros(size(value));
        mask = value < 0;
        sample(mask) = abs(value(mask));
    case 'traction'
        sample = zeros(size(value));
        mask = value > 0;
        sample(mask) = abs(value(mask));
    otherwise
        error('load_tire_table_data:BadCapabilityMode', 'Unsupported capability mode: %s', modeTag);
end

capGrid = accumarray([idxFz, idxGamma], sample, [numel(FzAxis), numel(gammaAxis)], @max, 0.0);

capModel = struct();
capModel.kind = 'capability';
capModel.inputNames = {'Fz', 'gamma'};
capModel.outputName = sprintf('%s_%s', valueField, modeTag);
capModel.minValues = [min(FzAxis), min(gammaAxis)];
capModel.maxValues = [max(FzAxis), max(gammaAxis)];
capModel.axes = {FzAxis, gammaAxis};
capModel.interpolant = griddedInterpolant({FzAxis, gammaAxis}, capGrid, 'linear', 'none');
capModel.nRows = numel(capGrid);
end

function model = local_build_nd_model(inputs, values, inputNames, outputName, label)
%LOCAL_BUILD_ND_MODEL 优先构建规则网格插值，不足时回退为 3D scattered。
axesCell = cell(size(inputs));
idxCell = cell(size(inputs));
gridSize = zeros(1, numel(inputs));
for i = 1:numel(inputs)
    [axesCell{i}, ~, idxCell{i}] = unique(inputs{i});
    gridSize(i) = numel(axesCell{i});
end

linMap = sub2ind(gridSize, idxCell{:});
if numel(unique(linMap)) ~= numel(values)
    error('load_tire_table_data:DuplicateRows', '%s contains duplicate grid rows.', label);
end

model = struct();
model.kind = 'scalar';
model.inputNames = inputNames;
model.outputName = outputName;
model.minValues = cellfun(@min, axesCell);
model.maxValues = cellfun(@max, axesCell);
model.axes = axesCell;
model.nRows = numel(values);

if numel(values) == prod(gridSize)
    gridValues = nan(gridSize);
    gridValues(linMap) = values;
    if all(isfinite(gridValues(:)))
        model.interpType = 'gridded';
        model.interpolant = griddedInterpolant(axesCell, gridValues, 'linear', 'none');
        return;
    end
end

if numel(inputs) == 3
    model.interpType = 'scattered';
    model.interpolant = scatteredInterpolant(inputs{1}, inputs{2}, inputs{3}, values, 'linear', 'none');
else
    error('load_tire_table_data:NeedRegularGrid', ...
        '%s requires a complete regular grid when more than three input dimensions are used.', label);
end
end

function F = local_build_4d_interpolant(alpha, kappa, Fz, gamma, value, label)
%LOCAL_BUILD_4D_INTERPOLANT 构造 CombinedTable 的 4D griddedInterpolant。
[alphaAxis, ~, idxAlpha] = unique(alpha);
[kappaAxis, ~, idxKappa] = unique(kappa);
[FzAxis, ~, idxFz] = unique(Fz);
[gammaAxis, ~, idxGamma] = unique(gamma);

gridSize = [numel(alphaAxis), numel(kappaAxis), numel(FzAxis), numel(gammaAxis)];
linIdx = sub2ind(gridSize, idxAlpha, idxKappa, idxFz, idxGamma);
if numel(unique(linIdx)) ~= numel(value)
    error('load_tire_table_data:CombinedDuplicate', '%s contains duplicate grid rows.', label);
end
if numel(value) ~= prod(gridSize)
    error('load_tire_table_data:CombinedNeedRegularGrid', ...
        '%s must contain a complete regular grid for alpha/kappa/Fz/gamma.', label);
end

gridValue = nan(gridSize);
gridValue(linIdx) = value;
if any(~isfinite(gridValue(:)))
    error('load_tire_table_data:CombinedIncompleteGrid', '%s grid contains missing values.', label);
end

F = griddedInterpolant({alphaAxis, kappaAxis, FzAxis, gammaAxis}, gridValue, 'linear', 'none');
end

function T = local_as_table(dataIn, label)
%LOCAL_AS_TABLE 将 table/struct 统一转换为 table。
if istable(dataIn)
    T = dataIn;
elseif isstruct(dataIn)
    T = struct2table(dataIn);
else
    error('load_tire_table_data:BadTableType', '%s must be a table or struct.', label);
end
end

function local_require_columns(T, requiredCols, label)
%LOCAL_REQUIRE_COLUMNS 强制要求列名显式存在，不允许隐式猜测。
vars = string(T.Properties.VariableNames);
required = string(requiredCols);
missing = required(~ismember(required, vars));
if ~isempty(missing)
    error('load_tire_table_data:MissingColumns', ...
        '%s is missing required columns: %s', label, strjoin(cellstr(missing), ', '));
end
end

function out = local_convert_input_column(data, fieldName, meta)
%LOCAL_CONVERT_INPUT_COLUMN 将输入列转换为 SI。
fieldKey = lower(strtrim(char(string(fieldName))));
switch fieldKey
    case 'alpha'
        out = local_convert_angle_column(data, local_get_with_default(meta, 'alphaUnit', 'rad'));
    case 'gamma'
        out = local_convert_angle_column(data, local_get_with_default(meta, 'gammaUnit', 'rad'));
    case 'kappa'
        out = local_convert_kappa_column(data, local_get_with_default(meta, 'kappaUnit', 'ratio'));
    case 'fz'
        out = local_convert_force_column(data, local_get_with_default(meta, 'FzUnit', 'N'));
    case 'pressure'
        out = local_convert_pressure_column(data, local_get_with_default(meta, 'pressureUnit', 'Pa'));
    otherwise
        out = double(data(:));
end
end

function out = local_convert_output_column(data, fieldName, meta)
%LOCAL_CONVERT_OUTPUT_COLUMN 将输出列转换为 SI。
fieldKey = lower(strtrim(char(string(fieldName))));
switch fieldKey
    case {'fx', 'fy', 'fz'}
        out = local_convert_force_column(data, local_get_with_default(meta, 'forceUnit', 'N'));
    case 'mz'
        out = local_convert_moment_column(data, local_get_with_default(meta, 'momentUnit', 'N*m'));
    otherwise
        out = double(data(:));
end
end

function out = local_convert_angle_column(data, unitName)
%LOCAL_CONVERT_ANGLE_COLUMN 角度列统一转 rad。
data = local_numeric_column(data);
switch local_normalize_unit_string(unitName)
    case 'deg'
        out = deg2rad(data);
    case 'rad'
        out = data;
    otherwise
        error('load_tire_table_data:BadAngleUnit', 'Unsupported angle unit: %s', unitName);
end
end

function out = local_convert_kappa_column(data, unitName)
%LOCAL_CONVERT_KAPPA_COLUMN 纵滑率统一转 ratio。
data = local_numeric_column(data);
switch local_normalize_unit_string(unitName)
    case {'ratio', 'unitless'}
        out = data;
    case {'pct', 'percent'}
        out = 0.01 * data;
    otherwise
        error('load_tire_table_data:BadKappaUnit', 'Unsupported kappa unit: %s', unitName);
end
end

function out = local_convert_force_column(data, unitName)
%LOCAL_CONVERT_FORCE_COLUMN 力统一转 N。
data = local_numeric_column(data);
switch local_normalize_unit_string(unitName)
    case 'n'
        out = data;
    case 'kn'
        out = 1e3 * data;
    otherwise
        error('load_tire_table_data:BadForceUnit', 'Unsupported force unit: %s', unitName);
end
end

function out = local_convert_moment_column(data, unitName)
%LOCAL_CONVERT_MOMENT_COLUMN 力矩统一转 N*m。
data = local_numeric_column(data);
switch local_normalize_unit_string(unitName)
    case {'n*m', 'nm'}
        out = data;
    case {'kn*m', 'knm'}
        out = 1e3 * data;
    otherwise
        error('load_tire_table_data:BadMomentUnit', 'Unsupported moment unit: %s', unitName);
end
end

function out = local_convert_pressure_column(data, unitName)
%LOCAL_CONVERT_PRESSURE_COLUMN 压力统一转 Pa。
data = local_numeric_column(data);
switch local_normalize_unit_string(unitName)
    case 'pa'
        out = data;
    case 'kpa'
        out = 1e3 * data;
    case 'bar'
        out = 1e5 * data;
    case 'psi'
        out = 6894.757293168 * data;
    otherwise
        error('load_tire_table_data:BadPressureUnit', 'Unsupported pressure unit: %s', unitName);
end
end

function out = local_numeric_column(data)
%LOCAL_NUMERIC_COLUMN 将 table/string/cellstr 列稳健转成 double 列向量。
if isnumeric(data)
    out = double(data(:));
elseif islogical(data)
    out = double(data(:));
elseif isstring(data)
    out = str2double(data(:));
elseif iscellstr(data) || iscell(data)
    out = str2double(string(data(:)));
else
    error('load_tire_table_data:BadColumnType', 'Unsupported column type in tire table data.');
end
end

function meta = local_parse_meta(metaIn)
%LOCAL_PARSE_META 支持 struct / 单行 table / key-value table。
if isempty(metaIn)
    meta = struct();
    return;
end
if isstruct(metaIn)
    meta = metaIn;
    return;
end
if ~istable(metaIn)
    error('load_tire_table_data:BadMetaType', 'Meta must be a struct or table.');
end

vars = string(metaIn.Properties.VariableNames);
meta = struct();
if height(metaIn) == 1
    for i = 1:numel(vars)
        meta.(char(vars(i))) = metaIn{1, i};
    end
    return;
end

if all(ismember(["key", "value"], lower(vars)))
    keyCol = vars(lower(vars) == "key");
    valueCol = vars(lower(vars) == "value");
    keys = string(metaIn.(keyCol{1}));
    values = metaIn.(valueCol{1});
elseif all(ismember(["name", "value"], lower(vars)))
    keyCol = vars(lower(vars) == "name");
    valueCol = vars(lower(vars) == "value");
    keys = string(metaIn.(keyCol{1}));
    values = metaIn.(valueCol{1});
else
    error('load_tire_table_data:BadMetaColumns', ...
        'Meta table must be single-row or use key/value style columns.');
end

for i = 1:numel(keys)
    key = matlab.lang.makeValidName(char(keys(i)));
    meta.(key) = values(i);
end
end

function meta = local_merge_meta_default(meta, fieldName, defaultValue)
%LOCAL_MERGE_META_DEFAULT 若 Meta 未提供字段，则回退到显式默认值。
if ~isfield(meta, fieldName) || isempty(meta.(fieldName))
    meta.(fieldName) = defaultValue;
end
end

function value = local_get_with_default(S, fieldName, defaultValue)
%LOCAL_GET_WITH_DEFAULT 从 struct 取值并提供默认值。
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function unitName = local_normalize_unit_string(unitName)
%LOCAL_NORMALIZE_UNIT_STRING 统一单位字符串大小写与空白。
unitName = lower(strtrim(char(string(unitName))));
end

function n = local_model_nrows(model)
%LOCAL_MODEL_NROWS 从模型结构中提取原始点数。
if isempty(model)
    n = 0;
elseif isfield(model, 'nRows')
    n = model.nRows;
else
    n = 0;
end
end

function filePath = local_resolve_input_path(fileIn)
%LOCAL_RESOLVE_INPUT_PATH 解析 forceModel.file 相对路径。
filePath = char(string(fileIn));
if isempty(filePath)
    return;
end
if isfile(filePath)
    return;
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
candidate = fullfile(rootDir, filePath);
if isfile(candidate)
    filePath = candidate;
    return;
end

candidate = fullfile(pwd, filePath);
if isfile(candidate)
    filePath = candidate;
end
end
