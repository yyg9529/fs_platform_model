function geom = build_corner_geometry(veh)
%BUILD_CORNER_GEOMETRY Build corner coordinates and geometry matrix V.
% 功能:
%   按固定角点顺序 FL/FR/RL/RR 构造角点坐标 (x_i, y_i) 与几何矩阵 V。
%
% 输入:
%   veh.lf, veh.lr, veh.tf, veh.tr
%
% 输出:
%   geom.names - {'FL','FR','RL','RR'}
%   geom.x     - [4x1] 角点 x 坐标 [m]（向前为正）
%   geom.y     - [4x1] 角点 y 坐标 [m]（向右为正）
%   geom.V     - [4x3] 每行 v_i = [1, x_i, y_i]
%
% 公式:
%   FL: x=+lf, y=-tf/2
%   FR: x=+lf, y=+tf/2
%   RL: x=-lr, y=-tr/2
%   RR: x=-lr, y=+tr/2

names = {'FL'; 'FR'; 'RL'; 'RR'};
x = [veh.lf; veh.lf; -veh.lr; -veh.lr];
y = [-veh.tf/2; veh.tf/2; -veh.tr/2; veh.tr/2];
V = [ones(4, 1), x, y];

geom = struct();
geom.names = names;
geom.x = x;
geom.y = y;
geom.V = V;
end
