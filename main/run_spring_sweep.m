function sweepOut = run_spring_sweep(baseCase, sweepDef, options)
%RUN_SPRING_SWEEP 执行前后弹簧二维扫参与四色分类整理。
% 功能说明:
%   1) 基于基准 case 生成前后弹簧组合网格。
%   2) 调用现有 run_batch 完成所有网格点求解。
%   3) 整理 quasi-static 与 bump-adjusted 两套 scrape map 分类结果。
%   4) 输出 resultGrid / summaryTable / classGrid / colorGrid / metadata。
%
% 输入:
%   baseCase  - 基准 caseDef
%   sweepDef  - 扫参定义结构体（见 build_spring_sweep_cases）
%   options   - 透传给 run_batch / run_case
%
% 输出:
%   sweepOut  - 扫参输出结构体
%
% 关键物理假设:
%   1) 本函数只做方案筛选层增强，不改写主求解器。
%   2) quasi-static 图与 bump-adjusted 图的区别仅在 scrape 判据不同。
%   3) 所有单点结果仍来自 run_case / run_batch。
%
% 单位约定:
%   内部一律使用 SI（N/m）；displayUnit 仅用于后续绘图显示。

if nargin < 3
    options = struct();
end

[caseList, metadata] = build_spring_sweep_cases(baseCase, sweepDef);
batchOut = run_batch(caseList, options);

resultGrid = batchOut.resultsList(metadata.indexGrid);
summaryTable = batchOut.summaryTable;

aeroPassGrid = logical(summaryTable.aeroPlatformPass(metadata.indexGrid));
scrapeQuasiGrid = logical(summaryTable.scrapePassQuasiStatic(metadata.indexGrid));
scrapeBumpGrid = logical(summaryTable.scrapePassBumpAdjusted(metadata.indexGrid));
validGrid = logical(summaryTable.ClassificationValid(metadata.indexGrid));

classQuasi = classify_spring_sweep_map(aeroPassGrid, scrapeQuasiGrid, validGrid);
classBump = classify_spring_sweep_map(aeroPassGrid, scrapeBumpGrid, validGrid);

sweepOut = struct();
sweepOut.frontSpringValues = metadata.frontSpringValues;
sweepOut.rearSpringValues = metadata.rearSpringValues;
sweepOut.resultGrid = resultGrid;
sweepOut.summaryTable = summaryTable;
sweepOut.classGridQuasiStatic = classQuasi.classCode;
sweepOut.labelGridQuasiStatic = classQuasi.classLabel;
sweepOut.colorGridQuasiStatic = classQuasi.colorGrid;
sweepOut.classGridBumpAdjusted = classBump.classCode;
sweepOut.labelGridBumpAdjusted = classBump.classLabel;
sweepOut.colorGridBumpAdjusted = classBump.colorGrid;
sweepOut.batchOut = batchOut;
sweepOut.metadata = metadata;
sweepOut.metadata.classPalette = classQuasi.palette;
sweepOut.metadata.classLabels = classQuasi.labels;
sweepOut.metadata.invalidClassCode = -1;
sweepOut.metadata.invalidClassLabel = "Not Evaluated";
sweepOut.metadata.invalidClassColor = classQuasi.invalidColor;
end
