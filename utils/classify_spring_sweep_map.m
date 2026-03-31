function classOut = classify_spring_sweep_map(aeroPlatformPass, scrapePass)
%CLASSIFY_SPRING_SWEEP_MAP 统一生成 spring sweep 四色分类编码、标签与颜色。
% 功能说明:
%   基于 aero 平台通过与 scrape 通过两个布尔输入，生成统一的四色分类：
%   0 = All Cases Fail
%   1 = Only Aero Passes
%   2 = Only Scrape Passes
%   3 = Both Cases Pass
%   本函数既可用于单点结果，也可用于 sweep 网格或 summary 向量。
%
% 输入:
%   aeroPlatformPass - 逻辑标量/数组，表示气动平台是否通过
%   scrapePass       - 逻辑标量/数组，表示 scrape 判据是否通过
%
% 输出:
%   classOut - 分类结果结构体：
%              .classCode  数值编码
%              .classLabel 字符串标签
%              .colorArray [N x 3] 或 [1 x 3] 颜色数组
%              .colorGrid  [size(classCode) 3] 颜色网格
%              .palette    [4 x 3] 固定颜色表
%              .labels     [4 x 1] 固定标签表
%
% 关键物理假设:
%   1) aeroPlatformPass 与 scrapePass 已由上游定义好，不在本函数中二次解释。
%   2) 颜色映射固定，避免图与表之间颜色漂移。
%
% 单位约定:
%   无量纲逻辑与分类编码；颜色为 RGB 三元组 [0,1]

if ~isequal(size(aeroPlatformPass), size(scrapePass))
    error('classify_spring_sweep_map:SizeMismatch', ...
        'aeroPlatformPass and scrapePass must have the same size.');
end

aeroPlatformPass = logical(aeroPlatformPass);
scrapePass = logical(scrapePass);

palette = [ ...
    0.55, 0.55, 0.55; ... % 0 All Cases Fail
    0.16, 0.42, 0.78; ... % 1 Only Aero Passes
    0.90, 0.56, 0.12; ... % 2 Only Scrape Passes
    0.15, 0.62, 0.28  ... % 3 Both Cases Pass
    ];
labels = [ ...
    "All Cases Fail"; ...
    "Only Aero Passes"; ...
    "Only Scrape Passes"; ...
    "Both Cases Pass" ...
    ];

classCode = zeros(size(aeroPlatformPass));
classCode(aeroPlatformPass & ~scrapePass) = 1;
classCode(~aeroPlatformPass & scrapePass) = 2;
classCode(aeroPlatformPass & scrapePass) = 3;

labelLinear = strings(numel(classCode), 1);
colorArray = zeros(numel(classCode), 3);
for i = 1:numel(classCode)
    idx = classCode(i) + 1;
    labelLinear(i) = labels(idx);
    colorArray(i, :) = palette(idx, :);
end

classLabel = reshape(labelLinear, size(classCode));
colorGrid = reshape(colorArray, [size(classCode), 3]);
if isscalar(classCode)
    colorArray = colorArray(1, :);
end

classOut = struct();
classOut.classCode = classCode;
classOut.classLabel = classLabel;
classOut.colorArray = colorArray;
classOut.colorGrid = colorGrid;
classOut.palette = palette;
classOut.labels = labels;
end
