function rad = deg2rad_safe(deg)
%DEG2RAD_SAFE Degree to radian conversion with numeric guard.

validateattributes(deg, {'numeric'}, {'real'}, mfilename, 'deg', 1);
rad = deg .* (pi / 180);
end
