function y = clamp_value(x, lo, hi)
%CLAMP_VALUE Clamp values into [lo, hi].
% 输入/输出单位:
%   与 x 相同；本函数不做单位变换。

if nargin < 2 || isempty(lo)
    lo = -inf;
end
if nargin < 3 || isempty(hi)
    hi = inf;
end

y = min(max(x, lo), hi);
end
