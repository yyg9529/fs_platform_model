function delta = calc_corner_deflections(q, geom)
%CALC_CORNER_DEFLECTIONS Compute corner vertical deflections.
% 功能:
%   根据车身状态 q=[z;theta;phi] 计算各角点位移 delta_i。
%
% 输入:
%   q    - [3x1], [z; theta; phi], 其中 z[m], theta/phi[rad]
%   geom - 含 V 矩阵，每行 v_i = [1, x_i, y_i]
%
% 输出:
%   delta - [4x1] 角点位移 [m]
%
% 公式:
%   delta_i = z + x_i*theta + y_i*phi

q = q(:);
if numel(q) ~= 3
    error('calc_corner_deflections:BadQ', 'q must be [z;theta;phi].');
end

delta = geom.V * q;
end
