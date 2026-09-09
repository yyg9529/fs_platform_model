function loadComp = calc_corner_load_components(caseDef, q, loads, corner)
%CALC_CORNER_LOAD_COMPONENTS Reconstruct complete dynamic ground-contact loads.
% The body posture solve contains only elastic spring forces and an ARB
% generalized roll moment.  This function allocates the bypass load paths
% required for tire-contact force and moment closure without feeding them
% back into the current 3-DOF posture solve.
%
% Corner order is [FL FR RL RR]. Positive Fz increases tire normal load.

veh = caseDef.veh;
phi = q(3);

FzElasticSpring = corner.Ftotal(:);

% Anti-roll bar axle moments are converted into left/right force pairs.
MArbFront = caseDef.sus.kArbF * phi;
MArbRear = caseDef.sus.kArbR * phi;
FzAntiRollBar = [ ...
    -MArbFront / veh.tf; ...
     MArbFront / veh.tf; ...
    -MArbRear / veh.tr; ...
     MArbRear / veh.tr];

% Quasi-static geometric lateral load transfer. man.ay is positive for a
% left turn (opposite the Cartesian y component because y is positive
% right). The axle lateral-force split is approximated by static weight.
FyFront = veh.m * caseDef.man.ay * veh.wf_static;
FyRear = veh.m * caseDef.man.ay * (1 - veh.wf_static);
MGeoFront = FyFront * veh.hRCf;
MGeoRear = FyRear * veh.hRCr;
FzRollCenterGeometric = [ ...
    -MGeoFront / veh.tf; ...
     MGeoFront / veh.tf; ...
    -MGeoRear / veh.tr; ...
     MGeoRear / veh.tr];

% Anti-dive/anti-lift/anti-squat changes the body elastic moment path, not
% the total ground-patch longitudinal load transfer. Allocate the bypass
% moment as equal left/right axle increments.
MDirectPitch = loads.pitch.Mpitch_xDirect;
frontAxleIncrement = MDirectPitch / veh.L;
rearAxleIncrement = -frontAxleIncrement;
FzAntiPitchGeometric = 0.5 * [ ...
    frontAxleIncrement; frontAxleIncrement; ...
    rearAxleIncrement; rearAxleIncrement];

FzDynamic = FzElasticSpring + FzAntiRollBar + ...
    FzRollCenterGeometric + FzAntiPitchGeometric;

loadComp = struct();
loadComp.FzElasticSpring = FzElasticSpring;
loadComp.FzAntiRollBar = FzAntiRollBar;
loadComp.FzRollCenterGeometric = FzRollCenterGeometric;
loadComp.FzAntiPitchGeometric = FzAntiPitchGeometric;
loadComp.FzDynamic = FzDynamic;
loadComp.MArbFront = MArbFront;
loadComp.MArbRear = MArbRear;
loadComp.MGeoFront = MGeoFront;
loadComp.MGeoRear = MGeoRear;
loadComp.assumptions = { ...
    'veh.m is treated as a lumped vehicle mass'; ...
    'lateral axle-force split equals static axle weight split'; ...
    'direct-path tire-compliance feedback is not coupled into q'};
end
