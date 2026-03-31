function pitch = calc_pitch_moment(caseDef, aero)
%CALC_PITCH_MOMENT Compute aero/drag/longitudinal pitch moments.
% 功能:
%   按给定公式计算总俯仰相关力矩分量。
%
% 输入:
%   caseDef.veh, caseDef.longi, caseDef.man.ax, caseDef.aero.hDrag
%   aero.FzFront, aero.FzRear, aero.Drag, aero.pitchMomentExtra
%
% 输出:
%   pitch struct:
%     Mpitch_aero, Mpitch_drag, Mpitch_x, eta
%
% 公式:
%   Mpitch_aero = lf*Fz_aero_f - lr*Fz_aero_r + Mpitch_extra
%   Mpitch_drag = Drag*hDrag
%   制动时:
%     eta_brake = brakeBiasF*antiDiveF + (1-brakeBiasF)*antiLiftR
%     Mpitch_x = -m*ax*hCG*(1-eta_brake)
%   加速时:
%     eta_drive = driveBiasR*antiSquatR
%     Mpitch_x = -m*ax*hCG*(1-eta_drive)

veh = caseDef.veh;
lon = caseDef.longi;
ax = caseDef.man.ax;

Mpitch_aero = veh.lf * aero.FzFront - veh.lr * aero.FzRear + aero.pitchMomentExtra;
Mpitch_drag = aero.Drag * caseDef.aero.hDrag;

if ax < 0
    eta = lon.brakeBiasF * lon.antiDiveF + (1 - lon.brakeBiasF) * lon.antiLiftR;
    Mpitch_x = -veh.m * ax * veh.hCG * (1 - eta);
else
    eta = lon.driveBiasR * lon.antiSquatR;
    Mpitch_x = -veh.m * ax * veh.hCG * (1 - eta);
end

pitch = struct();
pitch.Mpitch_aero = Mpitch_aero;
pitch.Mpitch_drag = Mpitch_drag;
pitch.Mpitch_x = Mpitch_x;
pitch.eta = eta;
end
