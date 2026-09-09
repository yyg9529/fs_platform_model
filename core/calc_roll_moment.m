function roll = calc_roll_moment(caseDef)
%CALC_ROLL_MOMENT Compute lateral inertial roll moment.
% 功能:
%   计算横向惯性导致的侧倾力矩 Mroll。
%
% 输入:
%   caseDef.veh.m, caseDef.man.ay, caseDef.veh.hCG, caseDef.derived.hRA_CG
%   man.ay is a signed turn input: positive means a left turn and therefore
%   right-side compression. With the geometric y-axis positive right,
%   a_y_cartesian = -man.ay.
%
% 输出:
%   roll.Mroll / MrollElastic - 使车身产生弹性侧倾的力矩 [N*m]
%   roll.MrollGeometric       - 通过侧倾中心直接传递的力矩 [N*m]
%   roll.MrollTotal           - 地面接触载荷必须闭合的总侧倾力矩 [N*m]
%
% 公式:
%   Mroll = m * ay_turn * (hCG - hRA_CG)

m = caseDef.veh.m;
ay = caseDef.man.ay;
hCG = caseDef.veh.hCG;
hRA_CG = caseDef.derived.hRA_CG;

MrollElastic = m * ay * (hCG - hRA_CG);
MrollGeometric = m * ay * hRA_CG;

roll = struct();
roll.Mroll = MrollElastic; % 向后兼容：主姿态方程仍使用弹性侧倾力矩
roll.MrollElastic = MrollElastic;
roll.MrollGeometric = MrollGeometric;
roll.MrollTotal = m * ay * hCG;
end
