function proxyOut = evaluate_tire_combined_proxy(FxPure, FyPure, FxCap, FyCap, proxyCfg)
%EVALUATE_TIRE_COMBINED_PROXY 用简化 combined-slip 代理折减纯表能力。
% 功能说明:
%   1) 当 V1.5 首版只有 pure Fy/Fx 表时，提供 brake-in-turn / accel-out 的近似能力评估。
%   2) 基于显式可配置的 friction-ellipse / utilization proxy 计算利用率与裁剪力。
%   3) 明确这是工程代理，不等价于完整 Magic Formula combined-slip。
%
% 输入:
%   FxPure   - 由纯纵滑表得到的目标 Fx [N]
%   FyPure   - 由纯侧偏表得到的目标 Fy [N]
%   FxCap    - 当前 Fz/gamma 下的纵向能力上限 [N]
%   FyCap    - 当前 Fz/gamma 下的侧向能力上限 [N]
%   proxyCfg - caseDef.tire.forceModel.combinedProxy 配置
%
% 输出:
%   proxyOut - 结构体，包含 clipped/requested/utilization/peakMargin 等
%
% 关键物理假设:
%   1) 纯表给出的是各自单独方向的能力。
%   2) combined 工况通过显式指数椭圆做代理，不求解完整 MF 参数耦合。
%   3) 若 demand 超出椭圆边界，则按统一缩放因子裁剪 Fx/Fy。
%
% 单位约定:
%   力 [N]；utilization / peakMargin 为无量纲

nExp = double(proxyCfg.exponent);
if ~isscalar(nExp) || ~isfinite(nExp) || nExp < 1
    error('evaluate_tire_combined_proxy:BadExponent', ...
        'combinedProxy.exponent must be a finite scalar >= 1.');
end
proxyType = lower(strtrim(char(string(proxyCfg.type))));
if ~strcmp(proxyType, 'friction_ellipse')
    error('evaluate_tire_combined_proxy:UnsupportedType', ...
        'Only combinedProxy.type=''friction_ellipse'' is implemented.');
end

FxCapEff = max(abs(FxCap), eps);
FyCapEff = max(abs(FyCap), eps);

uFx = abs(FxPure) ./ FxCapEff;
uFy = abs(FyPure) ./ FyCapEff;
constraintValue = uFx .^ nExp + uFy .^ nExp;
utilizationDemand = constraintValue .^ (1.0 / nExp);

scale = ones(size(constraintValue));
maskClip = constraintValue > 1.0;
scale(maskClip) = constraintValue(maskClip) .^ (-1.0 / nExp);

proxyOut = struct();
proxyOut.type = proxyType;
proxyOut.exponent = nExp;
proxyOut.requestedFx = FxPure;
proxyOut.requestedFy = FyPure;
proxyOut.clippedFx = FxPure .* scale;
proxyOut.clippedFy = FyPure .* scale;
proxyOut.constraintValue = constraintValue;
proxyOut.utilizationDemand = utilizationDemand;
proxyOut.utilization = min(utilizationDemand, 1.0);
proxyOut.scale = scale;
proxyOut.wasClipped = maskClip;

% peakMargin > 0 表示距离边界仍有余量，=0 贴边，<0 表示请求量已经超出纯表能力组合。
proxyOut.peakMargin = 1.0 - utilizationDemand;
end
