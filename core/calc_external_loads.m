function loads = calc_external_loads(caseDef, q, options)
%CALC_EXTERNAL_LOADS Build generalized external load vector Qext.
% 功能:
%   组合气动、纵向惯性俯仰、横向惯性侧倾，得到外载广义力 Qext。
%
% 输入:
%   caseDef - 预处理后的 caseDef
%   q       - 状态 [z;theta;phi]
%   options.frozenAero (可选) - 预先冻结的气动状态
%
% 输出:
%   loads struct:
%     .aero
%     .pitch
%     .roll
%     .Qext = [Qz;Qtheta;Qphi]
%     .Mpitch, .Mroll
%
% 公式:
%   Qz     = Fz_aero
%   Qtheta = Mpitch_aero + Mpitch_drag + Mpitch_x
%   Qphi   = Mroll

if nargin < 3
    options = struct();
end

if isfield(options, 'frozenAero') && ~isempty(options.frozenAero)
    aero = options.frozenAero;
else
    aero = calc_aero_state(caseDef, q);
end

pitch = calc_pitch_moment(caseDef, aero);
roll = calc_roll_moment(caseDef);

Qz = aero.Fz;
Qtheta = pitch.Mpitch_aero + pitch.Mpitch_drag + pitch.Mpitch_x;
Qphi = roll.Mroll;

loads = struct();
loads.aero = aero;
loads.pitch = pitch;
loads.roll = roll;
loads.Qext = [Qz; Qtheta; Qphi];
loads.Mpitch = Qtheta;
loads.Mroll = Qphi;
end
