function valOut = unit_convert(valIn, fromUnit, toUnit)
%UNIT_CONVERT Lightweight SI-oriented unit conversion helper.
% 支持示例:
%   mm <-> m, deg <-> rad, kN <-> N

key = sprintf('%s->%s', lower(strtrim(fromUnit)), lower(strtrim(toUnit)));

switch key
    case {'m->m', 'rad->rad', 'n->n', 'kg->kg', 'm/s->m/s', 'm/s^2->m/s^2'}
        factor = 1.0;
    case 'mm->m'
        factor = 1e-3;
    case 'm->mm'
        factor = 1e3;
    case 'deg->rad'
        factor = pi / 180;
    case 'rad->deg'
        factor = 180 / pi;
    case 'kn->n'
        factor = 1e3;
    case 'n->kn'
        factor = 1e-3;
    otherwise
        error('unit_convert:Unsupported', 'Unsupported conversion: %s', key);
end

valOut = valIn .* factor;
end
