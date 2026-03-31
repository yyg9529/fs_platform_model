function corner = calc_corner_forces(delta, sus, keq, useNonlinearCorner)
%CALC_CORNER_FORCES 计算 V1.0.3 角点主刚度力。
% 功能说明:
%   本版本角点力学仅保留主刚度项，不再在求解阶段引入 bump/droop 附加力。
%   为兼容旧接口，保留 Fbump/Fdroop/Ftotal 字段，但 Fbump/Fdroop 恒为零。
%
% 输入:
%   delta              - [4x1] 角点几何位移（ground-referenced）[m]
%   sus                - 悬架参数结构体（含 jounceMax/droopMax）
%   keq                - [4x1] 当前场景主平衡刚度 [N/m]
%   useNonlinearCorner - 兼容旧版本接口，V1.0.3 中停用
%
% 输出:
%   corner - 角点受力与行程相关量
%
% 关键物理假设:
%   1) DeltaF_i = keq_i * delta_i
%   2) bump/droop 概念仅兼容保留，不进入当前平衡方程
%
% 单位约定:
%   位移 [m]，力 [N]

if nargin < 4
    useNonlinearCorner = false;
end
if ~isempty(useNonlinearCorner) && logical(useNonlinearCorner)
    warning('calc_corner_forces:DeprecatedUseNonlinearCorner', ...
        'useNonlinearCorner is deprecated and ignored in V1.0.3.');
end

delta = delta(:);

% 主平衡力
Fmain = keq(:) .* delta;

% 兼容旧版本接口字段
Fbump = zeros(4, 1);
Fdroop = zeros(4, 1);
Ftotal = Fmain;

corner = struct();
corner.delta = delta;
corner.Fmain = Fmain;
corner.Fbump = Fbump;
corner.Fdroop = Fdroop;
corner.Ftotal = Ftotal;

% 兼容旧版本接口：在 V1.0.3 恒为 false
corner.bumpOn = false(4, 1);
corner.droopOn = false(4, 1);

corner.suspTravel = delta;               % deprecated 兼容字段
corner.tireDeflection = nan(4, 1);       % deprecated: 仅兼容保留

corner.jounceLimitOn = delta > sus.jounceMax(:);
corner.droopLimitOn = -delta > sus.droopMax(:);
end
