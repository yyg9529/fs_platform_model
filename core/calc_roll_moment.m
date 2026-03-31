function roll = calc_roll_moment(caseDef)
%CALC_ROLL_MOMENT Compute lateral inertial roll moment.
% 功能:
%   计算横向惯性导致的侧倾力矩 Mroll。
%
% 输入:
%   caseDef.veh.m, caseDef.man.ay, caseDef.veh.hCG, caseDef.derived.hRA_CG
%
% 输出:
%   roll.Mroll [N*m]
%
% 公式:
%   Mroll = m * ay * (hCG - hRA_CG)

m = caseDef.veh.m;
ay = caseDef.man.ay;
hCG = caseDef.veh.hCG;
hRA_CG = caseDef.derived.hRA_CG;

roll = struct();
roll.Mroll = m * ay * (hCG - hRA_CG);
end
