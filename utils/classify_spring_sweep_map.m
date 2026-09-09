function classOut = classify_spring_sweep_map(aeroPlatformPass, scrapePass, validMask)
%CLASSIFY_SPRING_SWEEP_MAP Build spring-sweep pass classes.
% Codes for evaluated points are 0=both fail, 1=aero only, 2=scrape only,
% and 3=both pass. Invalid/non-converged points use -1=Not Evaluated.

if ~isequal(size(aeroPlatformPass), size(scrapePass))
    error('classify_spring_sweep_map:SizeMismatch', ...
        'aeroPlatformPass and scrapePass must have the same size.');
end
if nargin < 3
    validMask = true(size(aeroPlatformPass));
elseif ~isequal(size(validMask), size(aeroPlatformPass))
    error('classify_spring_sweep_map:ValiditySizeMismatch', ...
        'validMask must have the same size as the pass arrays.');
end

aeroPlatformPass = logical(aeroPlatformPass);
scrapePass = logical(scrapePass);
validMask = logical(validMask);

palette = [ ...
    0.55, 0.55, 0.55; ...
    0.16, 0.42, 0.78; ...
    0.90, 0.56, 0.12; ...
    0.15, 0.62, 0.28];
labels = [ ...
    "All Cases Fail"; ...
    "Only Aero Passes"; ...
    "Only Scrape Passes"; ...
    "Both Cases Pass"];
invalidColor = [0.25, 0.25, 0.25];

classCode = zeros(size(aeroPlatformPass));
classCode(~validMask) = -1;
classCode(validMask & aeroPlatformPass & ~scrapePass) = 1;
classCode(validMask & ~aeroPlatformPass & scrapePass) = 2;
classCode(validMask & aeroPlatformPass & scrapePass) = 3;

labelLinear = repmat("Not Evaluated", numel(classCode), 1);
colorArray = repmat(invalidColor, numel(classCode), 1);
for i = 1:numel(classCode)
    if classCode(i) >= 0
        idx = classCode(i) + 1;
        labelLinear(i) = labels(idx);
        colorArray(i, :) = palette(idx, :);
    end
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
classOut.invalidColor = invalidColor;
end
