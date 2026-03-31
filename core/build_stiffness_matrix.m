function stiff = build_stiffness_matrix(sus, geom, tireDerived)
%BUILD_STIFFNESS_MATRIX 计算 V1.0.3 的角点刚度与广义刚度矩阵。
% 功能说明:
%   根据悬架参数和轮胎柔度模式得到每个角点的 kw、keq，并组装 K。
%
% 输入:
%   sus.ks, sus.mr, sus.kw(optional), sus.kArbF, sus.kArbR
%   geom.V（每行 v_i=[1, x_i, y_i]）
%   tireDerived.mode / tireDerived.ktUsed
%
% 输出:
%   stiff.kw  - 悬架侧轮端刚度 [N/m]
%   stiff.keq - 对地等效角点刚度 [N/m]
%   stiff.ktUsed - 当前场景使用的轮胎垂向刚度 [N/m]
%   stiff.K   - 广义刚度矩阵 [3x3]
%
% 关键物理假设:
%   1) kw = ks * mr^2
%   2) off 模式: keq = kw
%   3) fixed/range 单场景: keq = kw*kt/(kw+kt)
%
% 单位约定:
%   刚度 [N/m]、[N*m/rad]

if nargin < 3 || isempty(tireDerived)
    tireDerived = struct('mode', 'off', 'ktUsed', inf(4,1), 'tireComplianceIgnored', true);
end

if isempty(sus.kw)
    kw = sus.ks .* (sus.mr .^ 2);
else
    kw = sus.kw;
end
kw = kw(:);

modeStr = lower(strtrim(char(string(tireDerived.mode))));
ktUsed = inf(4,1);

switch modeStr
    case 'off'
        keq = kw;

    case {'fixed', 'range'}
        if ~isfield(tireDerived, 'ktUsed') || isempty(tireDerived.ktUsed)
            error('build_stiffness_matrix:MissingKt', 'tireDerived.ktUsed is required for mode=%s.', modeStr);
        end
        ktUsed = double(tireDerived.ktUsed(:));
        if numel(ktUsed) ~= 4 || any(~isfinite(ktUsed)) || any(ktUsed <= 0)
            error('build_stiffness_matrix:BadKt', 'tireDerived.ktUsed must be finite positive [4x1].');
        end
        keq = kw .* ktUsed ./ max(kw + ktUsed, eps);

    otherwise
        error('build_stiffness_matrix:BadMode', 'Unsupported tire mode: %s', modeStr);
end

K = zeros(3, 3);
for i = 1:4
    vi = geom.V(i, :);
    K = K + keq(i) .* (vi' * vi);
end

% ARB 追加侧倾刚度
K(3, 3) = K(3, 3) + sus.kArbF + sus.kArbR;

stiff = struct();
stiff.kw = kw;
stiff.keq = keq;
stiff.ktUsed = ktUsed;
stiff.tireMode = modeStr;
stiff.tireComplianceIgnored = strcmp(modeStr, 'off');
stiff.K = K;
end
