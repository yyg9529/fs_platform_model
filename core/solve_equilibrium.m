function solveOut = solve_equilibrium(caseDef)
%SOLVE_EQUILIBRIUM 求解 V1.0.2 的 R(q)=0 平衡方程。
% 功能说明:
%   1) 当 useAeroIter=false 时，外载视为常量，使用线性闭式解 Kq=Q。
%   2) 当 useAeroIter=true 时，使用阻尼 Newton 迭代处理气动耦合。
%
% 输入:
%   caseDef - 预处理后的结构体（含 derived.geom / derived.stiff）
%
% 输出:
%   solveOut - 包含 q、收敛状态、残差历史、求解器类型与调试信息
%
% 关键物理假设:
%   V1.0.2 中角点力线性化（无 bump/droop 附加力），主要非线性来自气动迭代。
%
% 单位约定:
%   q=[z;theta;phi]，其中 z[m], theta/phi[rad]

solver = caseDef.solver;
q = solver.initialGuess(:);
q = q(1:3);

iterHistory = zeros(solver.maxIter + 1, 4);
residualHistory = nan(solver.maxIter + 1, 1);

resOpt = struct('useNonlinearCorner', solver.useNonlinearCorner);
frozenLoads = [];
if ~solver.useAeroIter
    frozenLoads = calc_external_loads(caseDef, q, struct());
    resOpt.frozenLoads = frozenLoads;
end

% 线性快速路径（V1.0.2 中角点力始终线性，故仅由 useAeroIter 控制）
if ~solver.useAeroIter
    K = caseDef.derived.stiff.K;
    Qext = frozenLoads.Qext;
    if rcond(K) > 1e-12
        q = K \ Qext;
    else
        q = pinv(K) * Qext;
    end
    [R, ctx] = residual_equilibrium(caseDef, q, resOpt);

    solveOut = struct();
    solveOut.q = q;
    solveOut.converged = norm(R, 2) < solver.tol;
    solveOut.iterHistory = [0, q(:).'];
    solveOut.residualHistory = norm(R, 2);
    solveOut.lastResidual = R;
    solveOut.message = 'Linear closed-form solve used.';
    solveOut.solverUsed = 'linear_closed_form';
    solveOut.ctx = ctx;
    return;
end

converged = false;
message = 'Max iterations reached without convergence.';

for k = 1:solver.maxIter
    [R, ~] = residual_equilibrium(caseDef, q, resOpt);
    resNorm = norm(R, 2);

    iterHistory(k, :) = [k, q(:).'];
    residualHistory(k) = resNorm;

    if solver.verbose
        fprintf('[Iter %d] |R|=%.3e, q=[%.6e %.6e %.6e]\n', k, resNorm, q(1), q(2), q(3));
    end

    if resNorm < solver.tol
        converged = true;
        message = sprintf('Converged in %d iterations.', k);
        break;
    end

    J = finite_diff_jacobian(@(qq) residual_only(caseDef, qq, resOpt), q);
    if any(~isfinite(J), 'all')
        message = 'Jacobian contains non-finite values.';
        break;
    end

    if rcond(J) > 1e-12
        dq = -J \ R;
    else
        dq = -pinv(J) * R;
    end

    if any(~isfinite(dq))
        message = 'Newton step became non-finite.';
        break;
    end

    if norm(dq, 2) < solver.tol * 1e-2
        q = q + solver.relax * dq;
        converged = true;
        message = sprintf('Step small enough at iteration %d.', k);
        break;
    end

    % 阻尼步长搜索（选取残差更小者）
    alphas = unique([solver.relax, 0.5*solver.relax, 0.25*solver.relax, 0.1*solver.relax, 1.0], 'stable');
    bestQ = q;
    bestNorm = inf;
    for a = alphas
        qTry = q + a * dq;
        RTry = residual_only(caseDef, qTry, resOpt);
        nTry = norm(RTry, 2);
        if nTry < bestNorm
            bestNorm = nTry;
            bestQ = qTry;
        end
    end
    q = bestQ;
end

[Rfinal, ctxFinal] = residual_equilibrium(caseDef, q, resOpt);
if ~converged && norm(Rfinal, 2) < solver.tol
    converged = true;
    message = 'Converged at final residual check.';
end

validIter = iterHistory(:,1) > 0;
iterHistory = iterHistory(validIter, :);
residualHistory = residualHistory(validIter);

solveOut = struct();
solveOut.q = q;
solveOut.converged = converged;
solveOut.iterHistory = iterHistory;
solveOut.residualHistory = residualHistory;
solveOut.lastResidual = Rfinal;
solveOut.message = message;
solveOut.solverUsed = 'newton_damped';
solveOut.ctx = ctxFinal;
end

function J = finite_diff_jacobian(funR, q)
h = 1e-6 .* (1 + abs(q(:)));
R0 = funR(q);
J = zeros(3, 3);
for i = 1:3
    q1 = q;
    q1(i) = q1(i) + h(i);
    R1 = funR(q1);
    J(:, i) = (R1 - R0) ./ h(i);
end
end

function R = residual_only(caseDef, q, resOpt)
[R, ~] = residual_equilibrium(caseDef, q, resOpt);
end
