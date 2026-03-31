function deg = rad2deg_safe(rad)
%RAD2DEG_SAFE Radian to degree conversion with numeric guard.

validateattributes(rad, {'numeric'}, {'real'}, mfilename, 'rad', 1);
deg = rad .* (180 / pi);
end
