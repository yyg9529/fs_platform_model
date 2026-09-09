function [caseList, metadata] = build_spring_sweep_cases(baseCase, sweepDef)
%BUILD_SPRING_SWEEP_CASES 基于基准 case 生成前后弹簧二维扫参案例列表。
% 功能说明:
%   1) 读取前轴/后轴弹簧扫参序列。
%   2) 以前轴左右同值、后轴左右同值的方式修改 caseDef.sus.ks。
%   3) 生成供 run_batch / run_spring_sweep 使用的 case 列表与元数据。
%
% 输入:
%   baseCase  - 基准 caseDef
%   sweepDef  - 扫参定义结构体，至少包含：
%               .frontSpringSweep
%               .rearSpringSweep
%             可选：
%               .displayUnit ('N/m' | 'lbf/in')
%               .tag
%               .candidateRegion (struct: frontMin/frontMax/rearMin/rearMax)
%
% 输出:
%   caseList  - {nRear*nFront x 1} caseDef cell array
%   metadata  - 扫参与显示元数据
%
% 关键物理假设:
%   1) spring sweep 只是批处理筛选层，不是新求解器。
%   2) 扫参通过修改 sus.ks 完成；求解器内部仍使用现有 corner-based 结构。
%   3) 标准 sweep case 也尽量显式回写当前活跃字段，避免依赖 autofill warning。
%
% 单位约定:
%   内部一律使用 SI（N/m）；displayUnit 仅用于后续绘图显示。

if nargin < 2 || ~isstruct(sweepDef)
    error('build_spring_sweep_cases:BadInput', 'sweepDef must be a struct.');
end

frontSpringValues = normalize_sweep_vector(sweepDef, 'frontSpringSweep');
rearSpringValues = normalize_sweep_vector(sweepDef, 'rearSpringSweep');
displayUnit = get_optional_text(sweepDef, 'displayUnit', 'N/m');
tag = get_optional_text(sweepDef, 'tag', 'spring_sweep');

nFront = numel(frontSpringValues);
nRear = numel(rearSpringValues);
caseList = cell(nFront * nRear, 1);
indexGrid = nan(nRear, nFront);
idx = 0;
for iRear = 1:nRear
    for iFront = 1:nFront
        idx = idx + 1;
        caseI = baseCase;
        caseI.sus.ks(1:2) = frontSpringValues(iFront);
        caseI.sus.ks(3:4) = rearSpringValues(iRear);
        caseI.sus.kw = [];
        caseI.meta.name = sprintf('%s__kf_%g__kr_%g', baseCase.meta.name, ...
            frontSpringValues(iFront), rearSpringValues(iRear));
        caseI.meta.notes = sprintf('%s | V1.0.4 spring sweep front=%.6g N/m rear=%.6g N/m', ...
            baseCase.meta.notes, frontSpringValues(iFront), rearSpringValues(iRear));
        caseI.meta.springSweepFront = frontSpringValues(iFront);
        caseI.meta.springSweepRear = rearSpringValues(iRear);
        caseI.meta.springSweepFrontIndex = iFront;
        caseI.meta.springSweepRearIndex = iRear;
        caseList{idx} = caseI;
        indexGrid(iRear, iFront) = idx;
    end
end

metadata = struct();
metadata.baseCaseName = string(baseCase.meta.name);
metadata.baseCaseVersion = string(baseCase.meta.version);
metadata.tag = string(tag);
metadata.displayUnit = string(displayUnit);
metadata.frontSpringValues = frontSpringValues(:).';
metadata.rearSpringValues = rearSpringValues(:).';
metadata.nFront = nFront;
metadata.nRear = nRear;
metadata.indexGrid = indexGrid;
metadata.baselineFrontSpring = mean(baseCase.sus.ks(1:2));
metadata.baselineRearSpring = mean(baseCase.sus.ks(3:4));
if isfield(sweepDef, 'candidateRegion') && isstruct(sweepDef.candidateRegion)
    metadata.candidateRegion = sweepDef.candidateRegion;
else
    metadata.candidateRegion = struct();
end
end

function values = normalize_sweep_vector(sweepDef, fieldName)
%NORMALIZE_SWEEP_VECTOR 将 sweep 输入规范化为升序唯一行向量。
if ~isfield(sweepDef, fieldName)
    error('build_spring_sweep_cases:MissingField', '%s is required.', fieldName);
end
values = sweepDef.(fieldName);
if ~isnumeric(values) || isempty(values)
    error('build_spring_sweep_cases:BadSweep', '%s must be a non-empty numeric vector.', fieldName);
end
values = unique(sort(double(values(:)), 'ascend')).';
if any(~isfinite(values)) || any(values <= 0)
    error('build_spring_sweep_cases:BadSweepValue', '%s must contain finite positive values.', fieldName);
end
end

function txt = get_optional_text(sweepDef, fieldName, defaultValue)
%GET_OPTIONAL_TEXT 读取可选文本字段。
if isfield(sweepDef, fieldName) && ~isempty(sweepDef.(fieldName))
    txt = char(string(sweepDef.(fieldName)));
else
    txt = defaultValue;
end
end
