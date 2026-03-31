function [R, ctx] = residual_equilibrium(caseDef, q, options)
%RESIDUAL_EQUILIBRIUM 计算 V1.0.2 准静态平衡残差。
% 功能说明:
%   构造 R(q) = Qint(q) - Qext(q)，用于求解 R(q)=0。
%
% 输入:
%   caseDef - 预处理后的案例
%   q       - [z; theta; phi]
%   options.useNonlinearCorner - 兼容旧字段，V1.0.2 中不启用
%   options.frozenLoads        - 可选，冻结外载（如冻结气动）
%
% 输出:
%   R   - [3x1] 广义残差 [N, N*m, N*m]
%   ctx - 中间量（角点位移、角点力、外载等）
%
% 关键物理假设:
%   角点内力仅来自主刚度项（DeltaF = kw*delta）。
%
% 单位约定:
%   q: [m, rad, rad]

if nargin < 3
    options = struct();
end
if ~isfield(options, 'useNonlinearCorner')
    options.useNonlinearCorner = caseDef.solver.useNonlinearCorner;
end

geom = caseDef.derived.geom;
stiff = caseDef.derived.stiff;

delta = calc_corner_deflections(q, geom);
corner = calc_corner_forces(delta, caseDef.sus, stiff.keq, options.useNonlinearCorner);

% 广义内力: sum_i(F_i * v_i) = V' * F
Qint = geom.V' * corner.Ftotal;

% ARB 附加侧倾内力矩: M_arb = (kArbF + kArbR) * phi
MrollArb = (caseDef.sus.kArbF + caseDef.sus.kArbR) * q(3);
Qint(3) = Qint(3) + MrollArb;

if isfield(options, 'frozenLoads') && ~isempty(options.frozenLoads)
    loads = options.frozenLoads;
else
    loads = calc_external_loads(caseDef, q);
end
Qext = loads.Qext;

R = Qint - Qext;

ctx = struct();
ctx.q = q(:);
ctx.delta = delta;
ctx.corner = corner;
ctx.Qint = Qint;
ctx.loads = loads;
ctx.Qext = Qext;
ctx.R = R;
end
