function [S, missingFields] = ensure_fields(S, defaults, overwriteEmpty)
%ENSURE_FIELDS Fill missing struct fields with defaults (recursive).
% 功能:
%   递归检查结构体 S，若字段缺失（或可选地为空）则填入 defaults 中的默认值。
%
% 输入:
%   S             - 目标结构体
%   defaults      - 默认结构体
%   overwriteEmpty- true 时空值也会被默认值覆盖（默认 true）
%
% 输出:
%   S             - 补齐后的结构体
%   missingFields - 被补齐字段路径列表（cellstr）

if nargin < 3
    overwriteEmpty = true;
end
if isempty(S)
    S = struct();
end

missingFields = {};
defFields = fieldnames(defaults);

for i = 1:numel(defFields)
    f = defFields{i};
    defVal = defaults.(f);
    hasField = isfield(S, f);
    needFill = ~hasField || (overwriteEmpty && isempty(S.(f)));

    if needFill
        S.(f) = defVal;
        missingFields{end+1, 1} = f; %#ok<AGROW>
        continue;
    end

    % 递归补齐嵌套结构体
    if isstruct(defVal) && isstruct(S.(f))
        [S.(f), subMissing] = ensure_fields(S.(f), defVal, overwriteEmpty);
        for k = 1:numel(subMissing)
            missingFields{end+1, 1} = sprintf('%s.%s', f, subMissing{k}); %#ok<AGROW>
        end
    end
end
end
