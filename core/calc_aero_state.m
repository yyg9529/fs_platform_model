function aero = calc_aero_state(caseDef, q)
%CALC_AERO_STATE 计算姿态耦合气动状态（V1.0.3）。
% 功能说明:
%   根据 q=[z;theta;phi] 和工况参数，计算 hf/hr、Cz/Cd、Fz/Drag 与配平。
%   对 table_lookup 模式显式输出 clamp/fallback 标记，避免插值黑箱。
%
% 输入:
%   caseDef.aero, caseDef.ref, caseDef.man, caseDef.solver
%   q = [z; theta; phi]
%
% 输出:
%   aero - 气动状态结构体
%
% 关键物理假设:
%   1) hf = hAeroF0 - (z + xAeroF*theta)
%   2) hr = hAeroR0 - (z + xAeroR*theta)
%   3) Fz = 0.5*rho*V^2*Aref*Cz, Drag = 0.5*rho*V^2*Aref*Cd
%
% 单位约定:
%   hf/hr[m], 力[N], 力矩[N*m], 角度[rad]

z = q(1);
theta = q(2);
phi = q(3);

V = caseDef.man.V;
beta = caseDef.man.beta;

hf = caseDef.ref.hAeroF0 - (z + caseDef.ref.xAeroF * theta);
hr = caseDef.ref.hAeroR0 - (z + caseDef.ref.xAeroR * theta);

mapType = string(caseDef.aero.mapType);
mapData = caseDef.aero.mapData;
if ~isstruct(mapData)
    mapData = struct();
end

mapClampedAny = false;
interpFallbackUsed = false;
hfClamped = false;
hrClamped = false;
phiClamped = false;
betaClamped = false;
mapClampInfo = struct();

if mapType == "function_handle"
    CzFun = getfun(mapData, 'CzFun', @(hf_, hr_, phi_, beta_) 0.0);
    CdFun = getfun(mapData, 'CdFun', @(hf_, hr_, phi_, beta_) 0.0);
    frontShareFun = getfun(mapData, 'frontShareFun', @(hf_, hr_, phi_, beta_) 0.5);
    pitchMomentFun = getfun(mapData, 'pitchMomentFun', @(hf_, hr_, phi_, beta_) 0.0);

    Cz = CzFun(hf, hr, phi, beta);
    Cd = CdFun(hf, hr, phi, beta);
    frontShare = frontShareFun(hf, hr, phi, beta);
    pitchMomentExtra = pitchMomentFun(hf, hr, phi, beta);

elseif mapType == "table_lookup"
    % 气动地图插值层继续保持透明 flag 输出；
    % 若后续存在兼容字段差异，这里优先读取新字段并回退到旧字段名。
    interpOpt = struct('allowFallback', ~logical(caseDef.solver.errorOnInterpFailure));
    aeroMap = interp_aero_map(mapData, hf, hr, phi, beta, interpOpt);
    Cz = aeroMap.Cz;
    Cd = aeroMap.Cd;
    frontShare = aeroMap.frontShare;
    pitchMomentExtra = aeroMap.pitchMomentExtra;

    if isfield(aeroMap, 'mapClampedAny')
        mapClampedAny = logical(aeroMap.mapClampedAny);
    elseif isfield(aeroMap, 'mapClamped')
        mapClampedAny = logical(aeroMap.mapClamped);
    end
    if isfield(aeroMap, 'interpFallbackUsed')
        interpFallbackUsed = logical(aeroMap.interpFallbackUsed);
    end
    if isfield(aeroMap, 'hfClamped')
        hfClamped = logical(aeroMap.hfClamped);
    end
    if isfield(aeroMap, 'hrClamped')
        hrClamped = logical(aeroMap.hrClamped);
    end
    if isfield(aeroMap, 'phiClamped')
        phiClamped = logical(aeroMap.phiClamped);
    end
    if isfield(aeroMap, 'betaClamped')
        betaClamped = logical(aeroMap.betaClamped);
    end
    if isfield(aeroMap, 'mapClampInfo')
        mapClampInfo = aeroMap.mapClampInfo;
    end
else
    error('calc_aero_state:BadMapType', 'Unsupported mapType: %s', caseDef.aero.mapType);
end

frontShare = clamp_value(frontShare, 0.0, 1.0);
rearShare = 1.0 - frontShare;

qDynA = 0.5 * caseDef.aero.rho * V^2 * caseDef.aero.Aref;
Fz = qDynA * Cz;
Drag = qDynA * Cd;

FzFront = frontShare * Fz;
FzRear = rearShare * Fz;

aero = struct();
aero.hf = hf;
aero.hr = hr;
aero.Cz = Cz;
aero.Cd = Cd;
aero.Fz = Fz;
aero.Drag = Drag;
aero.frontShare = frontShare;
aero.rearShare = rearShare;
aero.FzFront = FzFront;
aero.FzRear = FzRear;
aero.pitchMomentExtra = pitchMomentExtra;

aero.mapClampedAny = mapClampedAny;
aero.mapClamped = mapClampedAny; % 兼容字段
aero.hfClamped = hfClamped;
aero.hrClamped = hrClamped;
aero.phiClamped = phiClamped;
aero.betaClamped = betaClamped;
aero.interpFallbackUsed = interpFallbackUsed;
aero.mapClampInfo = mapClampInfo;
end

function f = getfun(S, fName, fDefault)
if isfield(S, fName) && isa(S.(fName), 'function_handle')
    f = S.(fName);
else
    f = fDefault;
end
end
