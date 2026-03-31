function fig = plot_spring_sweep_map(sweepOut, mode, options)
%PLOT_SPRING_SWEEP_MAP 绘制前后弹簧 sweep 四色筛选图。
% 功能说明:
%   1) 支持 quasi-static 与 bump-adjusted 两套分类图。
%   2) 横轴为前轴弹簧扫参值，纵轴为后轴弹簧扫参值。
%   3) 可叠加基准方案点与候选区域矩形框。
%
% 输入:
%   sweepOut - run_spring_sweep 输出结构体
%   mode     - 'quasi_static' | 'bump_adjusted'
%   options  - 可选绘图参数：
%              .displayUnit ('N/m' | 'lbf/in')
%              .showBaseline (logical)
%              .candidateRegion (struct: frontMin/frontMax/rearMin/rearMax)
%              .markerSize
%              .titleSuffix
%
% 输出:
%   fig - 图窗句柄
%
% 关键物理假设:
%   1) 该图是方案筛选层可视化，不是新的物理求解器。
%   2) bump-adjusted 图中的 scrape 判据来自保守 bump 修正，而非完整瞬态模型。
%
% 单位约定:
%   sweepOut 内部 spring 值为 N/m；绘图可切换为 N/m 或 lbf/in。

if nargin < 2 || isempty(mode)
    mode = 'quasi_static';
end
if nargin < 3
    options = struct();
end

modeStr = lower(strtrim(char(string(mode))));
if ~isfield(options, 'displayUnit') || isempty(options.displayUnit)
    options.displayUnit = char(sweepOut.metadata.displayUnit);
end
if ~isfield(options, 'showBaseline')
    options.showBaseline = true;
end
if ~isfield(options, 'markerSize') || isempty(options.markerSize)
    options.markerSize = 420;
end
if ~isfield(options, 'titleSuffix')
    options.titleSuffix = '';
end
if ~isfield(options, 'candidateRegion') || isempty(options.candidateRegion)
    if isfield(sweepOut.metadata, 'candidateRegion')
        options.candidateRegion = sweepOut.metadata.candidateRegion;
    else
        options.candidateRegion = struct();
    end
end

switch modeStr
    case 'quasi_static'
        colorGrid = sweepOut.colorGridQuasiStatic;
        titleMain = 'Spring Sweep Map: Quasi-Static Scrape';
    case 'bump_adjusted'
        colorGrid = sweepOut.colorGridBumpAdjusted;
        titleMain = 'Spring Sweep Map: Bump-Adjusted Scrape Robustness';
    otherwise
        error('plot_spring_sweep_map:BadMode', 'Unsupported mode: %s', modeStr);
end

[frontValsPlot, unitLabel] = convert_spring_unit(sweepOut.frontSpringValues, options.displayUnit);
[rearValsPlot, ~] = convert_spring_unit(sweepOut.rearSpringValues, options.displayUnit);
[X, Y] = meshgrid(frontValsPlot, rearValsPlot);
colors = reshape(colorGrid, [], 3);

fig = figure('Name', ['Spring Sweep Map - ' modeStr], 'Color', 'w');
scatter(X(:), Y(:), options.markerSize, colors, 's', 'filled', 'MarkerEdgeColor', [0.20, 0.20, 0.20]);
hold on;

if logical(options.showBaseline)
    [baseFront, ~] = convert_spring_unit(sweepOut.metadata.baselineFrontSpring, options.displayUnit);
    [baseRear, ~] = convert_spring_unit(sweepOut.metadata.baselineRearSpring, options.displayUnit);
    scatter(baseFront, baseRear, 120, 'kp', 'filled', 'DisplayName', 'Baseline');
end

if isstruct(options.candidateRegion) && ~isempty(fieldnames(options.candidateRegion))
    rectPos = build_candidate_rectangle(options.candidateRegion, options.displayUnit);
    rectangle('Position', rectPos, 'EdgeColor', [0.1, 0.1, 0.1], 'LineStyle', '--', 'LineWidth', 1.3);
end

xlabel(sprintf('Front Spring Rate [%s]', unitLabel));
ylabel(sprintf('Rear Spring Rate [%s]', unitLabel));
title(strtrim(sprintf('%s %s', titleMain, options.titleSuffix)));
grid on;
box on;
set(gca, 'Layer', 'top');

legendHandles = gobjects(4, 1);
palette = sweepOut.metadata.classPalette;
labels = sweepOut.metadata.classLabels;
for i = 1:4
    legendHandles(i) = scatter(nan, nan, 120, palette(i, :), 's', 'filled', ...
        'MarkerEdgeColor', [0.20, 0.20, 0.20], 'DisplayName', char(labels(i)));
end
legend(legendHandles, cellstr(labels), 'Location', 'eastoutside');
hold off;
end

function [valuesOut, unitLabel] = convert_spring_unit(valuesIn, displayUnit)
%CONVERT_SPRING_UNIT 将 N/m 转为指定显示单位。
unitStr = lower(strtrim(char(string(displayUnit))));
switch unitStr
    case {'n/m', 'npm'}
        valuesOut = valuesIn;
        unitLabel = 'N/m';
    case {'lbf/in', 'lbfin', 'lbf per in'}
        valuesOut = valuesIn ./ 175.126835246476;
        unitLabel = 'lbf/in';
    otherwise
        error('plot_spring_sweep_map:BadDisplayUnit', 'Unsupported display unit: %s', displayUnit);
end
end

function rectPos = build_candidate_rectangle(candidateRegion, displayUnit)
%BUILD_CANDIDATE_RECTANGLE 将候选区域定义转为 rectangle 所需位置向量。
req = {'frontMin','frontMax','rearMin','rearMax'};
for i = 1:numel(req)
    if ~isfield(candidateRegion, req{i})
        error('plot_spring_sweep_map:BadCandidateRegion', ...
            'candidateRegion.%s is required when drawing candidate box.', req{i});
    end
end
[frontMin, ~] = convert_spring_unit(candidateRegion.frontMin, displayUnit);
[frontMax, ~] = convert_spring_unit(candidateRegion.frontMax, displayUnit);
[rearMin, ~] = convert_spring_unit(candidateRegion.rearMin, displayUnit);
[rearMax, ~] = convert_spring_unit(candidateRegion.rearMax, displayUnit);
rectPos = [frontMin, rearMin, frontMax - frontMin, rearMax - rearMin];
end
