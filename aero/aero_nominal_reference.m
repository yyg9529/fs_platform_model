function [FzNominal, frontShareNominal, validity] = aero_nominal_reference(nominalRef, V)
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
%   validity          - 字段存在性、有限性与速度域状态

validity = struct( ...
    'referenceProvided', false, ...
    'speedGridValid', false, ...
    'speedInRange', false, ...
    'fzProvided', false, ...
    'fzValid', false, ...
    'frontShareProvided', false, ...
    'frontShareValid', false);
FzNominal = nan;
frontShareNominal = nan;

if isa(nominalRef, 'function_handle')
    validity.referenceProvided = true;
    try
        out = nominalRef(V);
    catch
        return;
    end
    if isstruct(out)
        if isfield(out, 'FzNominal')
            FzNominal = out.FzNominal;
            validity.fzProvided = true;
        end
        if isfield(out, 'frontShareNominal')
            frontShareNominal = out.frontShareNominal;
            validity.frontShareProvided = true;
        end
    elseif isnumeric(out) && numel(out) >= 2
        FzNominal = out(1);
        frontShareNominal = out(2);
        validity.fzProvided = true;
        validity.frontShareProvided = true;
    else
        return;
    end
    validity.speedGridValid = true;
    validity.speedInRange = true;
    validity.fzValid = validity.fzProvided && is_finite_scalar(FzNominal) && FzNominal >= 0;
    validity.frontShareValid = validity.frontShareProvided && ...
        is_finite_scalar(frontShareNominal) && frontShareNominal >= 0 && frontShareNominal <= 1;
    return;
end

if ~isstruct(nominalRef) || ~isscalar(nominalRef)
    return;
end
validity.referenceProvided = ~isempty(fieldnames(nominalRef));

% 兼容字段名: VGrid/FzNominal/frontShareNominal
VGrid = [];
if isfield(nominalRef, 'VGrid'); VGrid = nominalRef.VGrid; end
if isempty(VGrid) && isfield(nominalRef, 'V'); VGrid = nominalRef.V; end

if isempty(VGrid)
    return;
end
VGrid = VGrid(:);
validity.speedGridValid = isnumeric(VGrid) && isreal(VGrid) && numel(VGrid) >= 2 && ...
    all(isfinite(VGrid)) && all(diff(VGrid) > 0);
if ~validity.speedGridValid
    return;
end
validity.speedInRange = is_finite_scalar(V) && V >= VGrid(1) && V <= VGrid(end);
if ~validity.speedInRange
    return;
end

if isfield(nominalRef, 'FzNominal')
    FzGrid = nominalRef.FzNominal;
    validity.fzProvided = true;
elseif isfield(nominalRef, 'Fz')
    FzGrid = nominalRef.Fz;
    validity.fzProvided = true;
else
    FzGrid = [];
end

if isfield(nominalRef, 'frontShareNominal')
    fsGrid = nominalRef.frontShareNominal;
    validity.frontShareProvided = true;
elseif isfield(nominalRef, 'frontShare')
    fsGrid = nominalRef.frontShare;
    validity.frontShareProvided = true;
else
    fsGrid = [];
end

if validity.fzProvided && isnumeric(FzGrid) && isreal(FzGrid) && ...
        numel(FzGrid) == numel(VGrid) && all(isfinite(FzGrid(:))) && all(FzGrid(:) >= 0)
    FzNominal = interp1(VGrid, FzGrid(:), V, 'linear');
    validity.fzValid = is_finite_scalar(FzNominal) && FzNominal >= 0;
end
if validity.frontShareProvided && isnumeric(fsGrid) && isreal(fsGrid) && ...
        numel(fsGrid) == numel(VGrid) && all(isfinite(fsGrid(:))) && ...
        all(fsGrid(:) >= 0 & fsGrid(:) <= 1)
    frontShareNominal = interp1(VGrid, fsGrid(:), V, 'linear');
    validity.frontShareValid = is_finite_scalar(frontShareNominal) && ...
        frontShareNominal >= 0 && frontShareNominal <= 1;
end
end

function tf = is_finite_scalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end
