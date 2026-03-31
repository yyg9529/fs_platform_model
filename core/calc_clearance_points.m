function clearance = calc_clearance_points(caseDef, q)
%CALC_CLEARANCE_POINTS 计算当前姿态下的动态离地高。
% 功能说明:
%   根据车身状态 q=[z;theta;phi] 计算各检查点的动态离地高，
%   并返回最小离地高及其位置。
%
% 输入:
%   caseDef.ref.xClear, yClear, hClear0
%   q = [z;theta;phi]
%
% 输出:
%   clearance.values [n x 1]
%   clearance.hMin
%   clearance.hMinName
%   clearance.names
%
% 公式:
%   hClear_j = hClear0_j - ( z + xClear_j*theta + yClear_j*phi )

z = q(1);
theta = q(2);
phi = q(3);

values = caseDef.ref.hClear0(:) - (z + caseDef.ref.xClear(:) .* theta + caseDef.ref.yClear(:) .* phi);
[hMin, idxMin] = min(values);

clearance = struct();
clearance.names = caseDef.ref.nameClear(:);
clearance.values = values;
clearance.hMin = hMin;
clearance.hMinName = clearance.names{idxMin};
end
