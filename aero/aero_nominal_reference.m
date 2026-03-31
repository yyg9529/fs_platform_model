function [FzNominal, frontShareNominal] = aero_nominal_reference(nominalRef, V)
%AERO_NOMINAL_REFERENCE Get nominal aero load and nominal front share vs speed.
% 功能:
%   供后处理计算 aeroLossPct / frontShareMigrationPct 使用。
%
% 输入:
%   nominalRef - 支持 function_handle 或 struct 表格
%   V          - 车速 [m/s]
%
% 输出:
%   FzNominal         - 参考下压力 [N]
%   frontShareNominal - 参考前轴下压力占比 [-]

if isa(nominalRef, 'function_handle')
    out = nominalRef(V);
    if isstruct(out)
        FzNominal = out.FzNominal;
        frontShareNominal = out.frontShareNominal;
    elseif isnumeric(out) && numel(out) >= 2
        FzNominal = out(1);
        frontShareNominal = out(2);
    else
        error('aero_nominal_reference:BadFunctionOutput', ...
            'nominalRef function output must be struct or numeric [FzNominal, frontShareNominal].');
    end
    return;
end

if ~isstruct(nominalRef)
    FzNominal = 0.0;
    frontShareNominal = 0.5;
    return;
end

% 兼容字段名: VGrid/FzNominal/frontShareNominal
VGrid = [];
if isfield(nominalRef, 'VGrid'); VGrid = nominalRef.VGrid; end
if isempty(VGrid) && isfield(nominalRef, 'V'); VGrid = nominalRef.V; end

if isempty(VGrid)
    FzNominal = 0.0;
    frontShareNominal = 0.5;
    return;
end

if isfield(nominalRef, 'FzNominal')
    FzGrid = nominalRef.FzNominal;
elseif isfield(nominalRef, 'Fz')
    FzGrid = nominalRef.Fz;
else
    FzGrid = zeros(size(VGrid));
end

if isfield(nominalRef, 'frontShareNominal')
    fsGrid = nominalRef.frontShareNominal;
elseif isfield(nominalRef, 'frontShare')
    fsGrid = nominalRef.frontShare;
else
    fsGrid = 0.5 .* ones(size(VGrid));
end

FzNominal = interp1(VGrid(:), FzGrid(:), V, 'linear', 'extrap');
frontShareNominal = interp1(VGrid(:), fsGrid(:), V, 'linear', 'extrap');
frontShareNominal = clamp_value(frontShareNominal, 0.0, 1.0);
end
