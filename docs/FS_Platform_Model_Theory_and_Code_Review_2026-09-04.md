# FS Platform Model 理论与代码全量审查报告

日期：2026-09-04  
审查基线：`main` / `105544d9f64bcc2a476e9de8c7a1dbdb22e7d69c`  
审查成果状态：基于上述 commit 的当前未提交 working-tree review patch；本文的修正与验证结论针对该工作区，不等同于仅检出基线 commit。未获授权，未 commit 或 push。  
审查对象：`fs_platform_model` 的理论假设、公式链、输入契约、求解器、后处理、轮胎代理、批处理、可视化和测试体系

## 1. 结论

本轮已完成理论推导核对、全仓代码审查、关键缺陷修正和双 MATLAB 版本回归。结论必须分层表达：

| 层级 | 状态 | 结论 |
|---|---|---|
| 代码主链可运行性 | PASS | 主入口、批处理、弹簧扫描和轮胎代理均通过当前自动化回归。 |
| 代数与准静态闭合 | CONDITIONAL PASS | 在本文明确的三自由度、小角度、线性角点刚度和集中质量假设下，姿态方程及修正后的接地载荷力/矩闭合。 |
| 参数与数据证据 | NOT READY | 随仓库提供的气动 map、nominal reference 和轮胎表均为 synthetic/demo 数据，不能代表实车标定。 |
| 整车工程签署 | NOT READY | 尚缺 sprung/unsprung 质量分离、直接载荷路径与轮胎柔度的统一耦合，以及真实气动/轮胎/台架或赛道数据验证。FSG 与中国系列赛事规则原文已找到，但必须按实际参赛赛事选择 profile。 |

因此，本项目现在可以用于软件回归、概念级趋势分析和发现不合格方案，但不能把任何结果直接称为实车设计签署或最终性能预测。

## 2. 证据状态定义

- `VERIFIED_CODE`：本轮已用当前代码和自动化测试复算。
- `PUBLIC_SOURCE`：有公开规则、大学材料、论文/学位论文或官方技术资料支持。
- `MODEL_ASSUMPTION`：为了维持当前 3-DOF 模型而显式采用的近似，不等价于实车事实。
- `SYNTHETIC_DATA`：仅用于 demo/test 的生成数据。
- `NOT READY`：缺少参数、模型维度或实测验证，不能用于工程签署。

## 3. 审查范围与架构

### 3.1 审查执行架构

- 理论审计：逐式核对坐标、单位、广义力、适用前提与公开资料的直接支持范围；
- 基线与解析验证：双 MATLAB 版本建立现有行为基线，并用 heave/pitch/roll、能量和接地载荷 oracle 独立复算；
- 程序审查：沿 validation → preprocess → solve → postprocess → tire/batch/sweep 检查数据契约、失效传播和分类语义；
- 主线集成：主审查者统一决定符号、接口和 fail-closed 规则，串行合入补丁并执行完整门禁；
- 独立复核：理论、架构与验证三路 reviewer 对最终工作区只读复查，确认前述阻塞项已闭环，并保留实测与模型维度缺口为 `NOT READY`。

### 3.2 程序主架构

审查后仓库含 112 个 MATLAB 文件，其中生产/示例代码 50 个、测试及测试辅助文件 62 个。主数据流为：

```text
caseDef
  -> validate_case_struct
  -> preprocess_case
       -> 角点几何 V
       -> wheel/tire 等效刚度
       -> 静态轮荷、行程和离地高派生量
  -> solve_equilibrium
       -> R(q) = Qint(q) - Qext(q)
       -> frozen-aero linear solve 或 scaled-residual damped Newton
  -> postprocess_results
       -> 完整角点接地载荷重构
       -> rules / targets / validity / classification
  -> optional tire force layer
       -> table load -> operating point -> interpolation/proxy -> result
  -> batch / spring sweep / visualization
```

主状态保持：

\[
q=\begin{bmatrix}z&\theta&\phi\end{bmatrix}^{T}
\]

当前坐标约定：

- 角点顺序固定为 `[FL, FR, RL, RR]`；
- \(x>0\) 向前，\(y>0\) 向右；
- \(z>0\) 表示车身下沉；
- \(\theta>0\) 表示车头下俯；
- \(\phi>0\) 表示车身向右侧倾；
- \(F_z>0\) 表示轮胎法向载荷增加；
- `man.ay` 是有符号转弯工况量，不是 Cartesian \(+y\) 加速度分量：

\[
a_{y,turn}>0\equiv\text{左转},\qquad
a_{y,Cartesian}=-a_{y,turn}
\]

  因此正 `man.ay` 对应右侧压缩、右轮增载和 \(\phi>0\)；
- 全部计算使用 SI，角度内部使用 rad。

侧偏角、纵滑率、轮胎力和回正力矩的完整 SAE 符号契约尚未写成单一规范，这是剩余缺口之一。

## 4. 理论推导与代码对应

### 4.1 刚体平面与角点位移

小角度下，车身参考平面在角点 \((x_i,y_i)\) 的向下位移为：

\[
\delta_i=z+x_i\theta+y_i\phi
\]

令：

\[
v_i^T=\begin{bmatrix}1&x_i&y_i\end{bmatrix},\qquad
V=\begin{bmatrix}v_1^T\\v_2^T\\v_3^T\\v_4^T\end{bmatrix}
\]

则：

\[
\delta=Vq
\]

这是刚体、小角度、一阶几何关系；它不含底板挠曲、悬架硬点运动学、轮胎包络或路面输入。代码对应 `core/build_corner_geometry.m` 与 `core/calc_corner_deflections.m`。

### 4.2 Motion ratio 与轮端刚度

项目采用局部微分 installation ratio：

\[
mr=\frac{dx_s}{dx_w}
\]

由虚功或杠杆平衡：

\[
F_w\,dx_w=F_s\,dx_s
\Rightarrow F_w=F_s\frac{dx_s}{dx_w}=F_s mr
\]

因此局部切线轮端刚度为：

\[
k_w=\frac{dF_w}{dx_w}
=k_smr^2+F_s\frac{dmr}{dx_w}
\]

只有当所分析行程内 \(mr\) 可视为常数时，才退化为 \(k_w=k_smr^2\)。这一写法不隐含弹簧零预载。虚功关系及 installation ratio 的局部定义可与 Bucchi 与 Lenzo 的同行评审论文 [*Analytical Derivation and Analysis of Vertical and Lateral Installation Ratios for Swing Axle, McPherson and Double Wishbone Suspension Architectures*](https://www.mdpi.com/2076-0825/11/8/229) 交叉核对。若采用倒数定义 \(mr=dx_w/dx_s\)，平方关系也必须相应取倒数。

代码已把 `ks` 与 `mr` 设为权威输入；若同时提供 `kw`，必须与 `ks.*mr.^2` 一致，否则 validation 失败，避免双数据源。

### 4.3 悬架与轮胎垂向柔度串联

同一角点力 \(F\) 通过悬架轮端刚度 \(k_w\) 和轮胎垂向刚度 \(k_t\)，总位移为：

\[
\delta=\frac{F}{k_w}+\frac{F}{k_t}
\]

所以：

\[
\frac{1}{k_{eq}}=\frac{1}{k_w}+\frac{1}{k_t},\qquad
k_{eq}=\frac{k_wk_t}{k_w+k_t}
\]

该推导与 [MIT OpenCourseWare 的两线性弹簧串联推导](https://ocw.mit.edu/courses/1-105-solid-mechanics-laboratory-fall-2003/0f895868598a52276cafb4875f9c277b_exp3_03.pdf) 以及 [Altair MotionView 的 wheel/ride rate 技术说明](https://help.altair.com/hwdesktop/hwx/topics/motionview/sdf_wheel_rate_ride_rate_and_hop_rate_r.htm) 一致。代码对应 `core/build_stiffness_matrix.m`。

边界：当前 `fixed/range` 仍把每角点轮胎柔度与主弹簧路径等效串联，再另加 ARB 广义力矩。若要求严格处理 ARB 左右耦合与轮胎柔度，应建立角点 4×4 悬架矩阵 \(S\) 与轮胎矩阵 \(T\)：

\[
E=(S^{-1}+T^{-1})^{-1},\qquad K_q=V^TEV
\]

该升级尚未实现，状态为 `NOT READY`。

### 4.4 广义刚度与内力

角点等效弹性势能为：

\[
U=\frac12\delta^TE\delta+\frac12K_{\phi,ARB}\phi^2,
\qquad E=\operatorname{diag}(k_{eq,i})
\]

代入 \(\delta=Vq\)：

\[
U=\frac12q^TV^TEVq+\frac12K_{\phi,ARB}\phi^2
\]

对 \(q\) 求偏导：

\[
Q_{int}=\frac{\partial U}{\partial q}
=\left[V^TEV+\operatorname{diag}(0,0,K_{\phi,ARB})\right]q
\]

因此主刚度矩阵为：

\[
K=V^TEV+\operatorname{diag}(0,0,k_{ARB,F}+k_{ARB,R})
\]

这与 `core/build_stiffness_matrix.m`、`core/residual_equilibrium.m` 一致。多自由度刚度矩阵的串并联原则也可参照 [MIT OpenCourseWare, Precision Engineering Principles](https://ocw.mit.edu/courses/2-76-multi-scale-system-design-fall-2004/3aa5862a1724b75c3e4aa7a6fee6c511_reading_l3.pdf)。

### 4.5 气动力

动压：

\[
q_a=\frac12\rho V^2
\]

下压力与阻力：

\[
F_a=q_aAC_z,\qquad D=q_aAC_d
\]

NASA Glenn 的 [dynamic pressure](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/dynamic-pressure/) 与 [drag coefficient](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-coefficient/) 资料给出了同一标准形式，并说明 \(V\) 应为物体相对气流速度。本项目只把正 \(C_z\) 定义为向下力；`Cz`、`Cd`、front share、参考面积和力矩参考点必须来自同一车身姿态、偏航角和车辆配置的数据。

气动参考点离地高采用：

\[
h_f=h_{f0}-(z+x_f\theta),\qquad
h_r=h_{r0}-(z+x_r\theta)
\]

气动俯仰广义力矩：

\[
M_{aero}=l_fF_{a,f}-l_rF_{a,r}+M_{extra}
\]

阻力作用线贡献：

\[
M_D=D h_D
\]

其中 `hDrag` 必须解释为相对 CG 的有符号垂向偏置；`pitchMomentExtra` 必须是未被 front-share 分配包含的残余力矩，避免双计。

### 4.6 纵向载荷转移与 anti geometry

整车接地点必须承担的纵向惯性俯仰广义力为：

\[
Q_{\theta,total}=M_{pitch,total}=-ma_xh_{CG}
\]

对应前后轴法向载荷变化：

\[
\Delta F_{z,F}=\frac{Q_{\theta,total}}{L},\qquad
\Delta F_{z,R}=-\Delta F_{z,F}
\]

这一整车力矩平衡可参照 Chalmers University of Technology 的 [Compendium in Vehicle Motion Engineering](https://research.chalmers.se/publication/532725/file/532725_Fulltext.pdf)。它决定的是前后轴总法向载荷；气动力压力中心、阻力作用高度或其他外部俯仰力矩必须另行显式加入。

anti-dive / anti-lift / anti-squat 改变的是力矩通过弹簧路径和悬架连杆路径的分配，不会消除整车接地点必须闭合的总载荷转移。当前模型定义：

\[
Q_{\theta,elastic}=Q_{\theta,total}(1-\eta),\qquad
Q_{\theta,direct}=Q_{\theta,total}\eta
\]

制动时：

\[
\eta=b_F\,antiDive_F+(1-b_F)\,antiLift_R
\]

加速时：

\[
\eta=d_R\,antiSquat_R
\]

该加速式只在后轮驱动，或明确假设前轴驱动份额的 direct anti-lift 为零时成立；当前接口没有 `antiLiftFDrive`，所以 `driveBiasR<1` 时按后一假设处理并发出 warning。若未来增加前轴驱动 anti 项，一般式应把前、后轴驱动份额都纳入加权。

主姿态方程只使用 \(Q_{\theta,elastic}\)，后处理把 \(Q_{\theta,direct}\) 通过前后轴接地载荷回填。代码因历史原因仍使用 `Mpitch_x*` 字段名，其中 `x` 表示纵向来源，不表示绕 x 轴。Altair 的官方技术说明分别给出 [anti-dive/lift](https://help.altair.com/2022/hwdesktop/hwx/topics/motionview/sdf_anti-dive_lift_and_brake_dive_lift_r.htm) 与 [anti-lift/squat](https://help.altair.com/hwdesktop/hwx/topics/motionview/sdf_anti-lift_squat_and_acceleration_lift_squat_r.htm) 的几何定义：100% anti 是几何路径力矩抵消车身俯仰趋势，不是把整车轴荷转移消掉。当前 \(\eta\) 是项目给定代理，不是由实际硬点、制动器安装位置和扭矩反力路径求解所得。

### 4.7 横向载荷转移、roll center 与 ARB

整车接地点必须闭合：

\[
Q_{\phi,total}=M_{roll,total}=m a_{y,turn}h_{CG}
\]

当前线性 roll-axis 高度：

\[
h_{RA}=w_fh_{RC,F}+(1-w_f)h_{RC,R}
\]

该式不是任意轴荷比例下的通用 roll-axis 几何公式；它在本项目成立，是因为预处理强制 \(w_f=l_r/L\)，并同时假设横向力按静态轴荷分配。

弹性和几何路径：

\[
Q_{\phi,elastic}=m a_{y,turn}(h_{CG}-h_{RA}),\qquad
Q_{\phi,geo}=m a_{y,turn}h_{RA}
\]

这一分解及“总载荷转移不因弹性/几何路径分配而消失”的边界，可参照 Claude Rouelle 的 [The No Way Transfer, Part 2](https://optimumg.com/wp-content/uploads/2021/10/OptimumG-Septepmber-2021.pdf)。该资料是专业技术文章，不是同行评审论文；本报告只用它支持路径分解概念。

当前按静态轴荷比例近似横向力分配：

\[
F_{y,F}=m a_{y,turn}w_f,\qquad F_{y,R}=m a_{y,turn}(1-w_f)
\]

几何载荷转移力对：

\[
\Delta F_{RC,F}=\frac{F_{y,F}h_{RC,F}}{t_f}
\begin{bmatrix}-1&1\end{bmatrix}^{T}
\]

后轴同理。ARB 载荷力对为：

\[
M_{ARB,F}=k_{ARB,F}\phi,\qquad
\Delta F_{ARB,F}=\frac{M_{ARB,F}}{t_f}
\begin{bmatrix}-1&1\end{bmatrix}^{T}
\]

后轴同理。这样，完整动态角点接地载荷为：

\[
\Delta F_z=\Delta F_{spring}+\Delta F_{ARB}
+\Delta F_{RC}+\Delta F_{anti}
\]

并按广义力顺序 \([F_z,Q_\theta,Q_\phi]^T\) 满足：

\[
V^T\Delta F_z=
\begin{bmatrix}
F_a\\
M_{aero}+M_D+Q_{\theta,total}\\
Q_{\phi,total}
\end{bmatrix}
\]

代码对应新增的 `core/calc_corner_load_components.m`。这修复了原代码只把弹簧力写入 `FzWheel`、却把 ARB/roll-center/anti 路径留在姿态方程外的问题。

重要边界：轴向横向力当前按静态轴荷比例分配，且 `veh.m` 被视为集中总质量；没有簧上/簧下质量分离，因此只可作为准静态一阶代理。

### 4.8 离地高与行程规则

清地点 \((x_j,y_j,h_{j0})\) 的一阶离地高：

\[
h_j=h_{j0}-(z+x_j\theta+y_j\phi)
\]

FSG 2026 v1.1 的规则证据已拆到输入与结果：

- T2.2.1：含驾驶员时，除轮胎外的车辆最小静态离地间隙为 30 mm；主动悬架按最低可调位置测量。
- T2.5.1：车手就座条件下，可用轮端行程至少 50 mm，且 minimum jounce 至少 25 mm；前后悬架必须完全可用并包含减振器。

官方来源：[Formula Student Rules 2026 v1.1](https://www.formulastudent.de/fileadmin/user_upload/all/2026/rules/FS-Rules_2026_v1.1.pdf)。这些数值是下限，不表示行程必须等于 50/25 mm，也不等于减振器行程必须为同一数值。

中国汽车工程学会发布的 [2026 中国大学生方程式系列赛事规则（最终版）](https://img.sae-china.org/web/2026/04/2026%E4%B8%AD%E5%9B%BD%E5%A4%A7%E5%AD%A6%E7%94%9F%E6%96%B9%E7%A8%8B%E5%BC%8F%E7%B3%BB%E5%88%97%E8%B5%9B%E4%BA%8B%E8%A7%84%E5%88%99%EF%BC%88%E6%9C%80%E7%BB%88%E7%89%88%EF%BC%89.pdf) 是适用于 FSCC/FSEC/FSAC 的独立规则：T3.2.1 要求有车手时静态离地间隙至少 30 mm；T3.1.1 要求有车手时轮胎跳动行程至少 50 mm，并要求悬架与减振器功能正常，但最终版未见独立的 25 mm minimum-jounce 条款；A3.3.5 明确了中国规则的独立适用性。两套规则均出现驾驶员条件下的 \(\ge50\,mm\) 行程阈值，但措辞、测量项和附加要求不同，不能互相替代。因此当前默认 profile 只声明 `FSG_2026_v1.1`；参加中国系列赛事时，25 mm 只能作为项目保守目标，不能写成中国规则条款。

### 4.9 轮胎 combined-slip 代理

当前 friction-ellipse/superellipse 代理：

\[
d=\left|\frac{F_x}{F_{x,cap}}\right|^n+
\left|\frac{F_y}{F_{y,cap}}\right|^n
\]

其定义域要求 \(F_{x,cap}>0\)、\(F_{y,cap}>0\)。代码现强制 \(n\ge1\)，以保证通常所需的凸可行域；\(0<n<1\) 的非凸边界被输入校验拒绝。

真正的径向利用率：

\[
r=d^{1/n}
\]

若 \(d>1\)，统一缩放：

\[
s=d^{-1/n},\qquad (F_x,F_y)_{out}=s(F_x,F_y)_{requested}
\]

并定义：

\[
margin=1-r
\]

[Ghandriz 等的同行评审论文 *Computationally Efficient Nonlinear One- and Two-Track Models for Multitrailer Road Vehicles*](https://doi.org/10.1109/ACCESS.2020.3037035) 支持 \(n=2\) 的 friction circle/ellipse 形式；任意 \(n\ne2\) 在本项目中只能视为经验 superellipse 代理，不能声称来自该论文。[Matthew Van Gennip 2018 年 University of Waterloo 学位论文 *Vehicle Dynamic Modelling and Parameter Identification for an Autonomous Vehicle*](https://dspacemainprd01.lib.uwaterloo.ca/server/api/core/bitstreams/9a00429e-8e84-4468-a3ef-b2e92c671e0d/content) 提供椭圆可行域和固定胎压试验的背景例证。项目拒绝压力扫描和偏离参考胎压查询的直接原因，是当前仓库轮胎表 schema 没有压力维度或经验证的压力修正模型；学位论文不是该软件约束的因果依据。

当前轮胎层仍是 open-loop operating-point 查询：`man.ax/ay` 不会反求 `alpha/kappa`，也不求解横摆、转向、轮速或力平衡。因此它是代理筛选层，不是车辆可实现加速度的闭环证明。

### 4.10 求解器收敛判据

原实现直接对 `[N, N*m, N*m]` 求二范数，并可因 Newton 步长很小而误报收敛。修正后采用无量纲残差：

\[
\hat R=
\begin{bmatrix}
R_F/(mg)\\
R_{pitch}/(mgL)\\
R_{roll}/(mg\,t_{max}/2)
\end{bmatrix},\qquad
\|\hat R\|_2<tol
\]

小步长只有在更新后的缩放残差也满足容差时才可收敛，否则标记 stagnation。线搜索同样比较缩放残差。原始与缩放残差均保存在 `results.debug`。

## 5. 关键数值复算：2026 target

工况：\(V=24\,m/s\)、\(a_x=-3\,m/s^2\)、\(a_{y,turn}=10\,m/s^2\)（左转）。

### 5.1 姿态与求解残差

\[
q=\begin{bmatrix}
0.007224092666\\
0.002144538529\\
0.009597771076
\end{bmatrix}
\]

- pitch = 0.122873 deg；
- roll = 0.549912 deg；
- 原始最终残差范数 = \(2.706\times10^{-11}\)；
- 缩放最终残差范数 = \(6.714\times10^{-15}\)。

### 5.2 修正前后接地载荷

| 项目 | FL | FR | RL | RR | 单位 |
|---|---:|---:|---:|---:|---|
| 修正前 `FzWheel` | 688.538 | 1101.539 | 692.006 | 1149.957 | N |
| 修正后 `FzWheel` | 657.382 | 1172.518 | 593.057 | 1209.083 | N |
| 弹簧路径动态分量 | 108.276 | 521.278 | -3.033 | 454.919 | N |
| ARB 路径 | -22.446 | 22.446 | -19.995 | 19.995 | N |
| roll-center 几何路径 | -28.621 | 28.621 | -59.042 | 59.042 | N |
| anti-pitch 直接路径 | 19.911 | 19.911 | -19.911 | -19.911 | N |

修正后动态轮荷的广义闭合：

\[
V^T\Delta F_z=
\begin{bmatrix}
1081.439821\\
280.167590\\
689.000000
\end{bmatrix}
\]

与完整外部下压力、俯仰力矩和侧倾力矩一致。原输出只体现约 217.248 N·m 俯仰分量和 530.832 N·m 侧倾分量，分别遗漏 anti 直接路径以及 ARB/roll-center 路径。

### 5.3 当前 target 判定拆解

失败项：

- 静态最小离地高 = 25 mm，小于 FSG T2.2.1 和中国规则 T3.2.1 的 30 mm；
- 当前气动 map 在该速度输出 \(F_z=1081.440\,N\)；nominal reference 为 2784 N；损失 61.155%；
- 该 map 的最大 \(C_z\) 对应理论最小损失仍为 56.355%，高于 target 的 25%，所以随仓库数据下目标不可达；
- 数据状态为 `synthetic_demo`。

已通过的当前模型数值检查：

- effective total travel = 70.652 mm，高于 50 mm 阈值，`usableWheelTravelPass=true`；
- minimum effective jounce = 40.426 mm，高于 FSG 的 25 mm 阈值，`minJouncePass=true`；中国 2026 最终版本身没有该独立 25 mm 条款。

最终状态：`analysisReady=true`、`platformFeasible=false`（兼容字段 `feasible=false`）、`engineeringReady=false`。这一区分表示计算结果可审查，但方案不满足约束且模型/数据仍未达到工程签署门禁。

上述行程数值不是赛事合规证明：当前模型没有证明车手就座测量条件、悬架完全可用、机械限位与干涉、减振器安装边界或实车测量结果。

## 6. 本轮发现与修正

| 优先级 | 缺陷 | 修正 | 验证 |
|---|---|---|---|
| P0 | Newton 小步长可在大残差下误报收敛；残差混合量纲 | 无量纲残差、更新后复核、stagnation 终止、缩放线搜索 | 奇异 roll 恢复路径回归 |
| P0 | `FzWheel` 缺失 ARB、roll-center、anti 直接路径 | 新增完整角点接地载荷重构与广义力/矩闭合 | heave/pitch/roll 数值 oracle |
| P0 | 负轮荷仍可能 `feasible=true` | `Fz<=0` 阻断 validity、classification 和 feasible | 40 m/s² 横向哨兵测试 |
| P1 | 弹簧扫描用 `reshape` 错配非方阵格点 | 使用显式 `indexGrid` | 3×2 唯一值网格测试 |
| P1 | 非收敛/插值降级案例仍可进入绿色分类 | 增加 `classificationValid` 和 `Not Evaluated=-1` | nonconverged/clamped/contact-lost 测试 |
| P1 | `ks`、`mr`、`kw` 是冲突双数据源 | `kw=[]` 时统一派生；显式 `kw` 必须一致 | 不一致输入拒绝测试 |
| P1 | 胎压输入/扫描对力无作用却看似有效 | 无压力维度时拒绝压力扫描或非参考压力 | 压力契约测试 |
| P1 | 运行点胎压单位可能与表参考单位混用 | 运行点归一化时统一转 Pa，同时保留 source metadata 原始值/单位 | 83 kPa → 83000 Pa 回归 |
| P1 | 缺失气动判据或 front-share reference 时可假通过分类 | 分离 criteria-defined/evaluable；缺失、越域或零速时分类为 `Not Evaluated=-1` | 空判据、缺字段、禁止外推测试 |
| P1 | `engineeringReady` 可被用户填写的 evidence 字符串置真 | 在模型级架构/实测门禁未实现前固定 fail-closed；另暴露 `platformFeasible` | spoofed validated evidence 测试 |
| P1 | roll-center、anti、bias、`hDrag` 和 provenance 缺少输入校验 | 增加有限性、范围、轴距一致性、枚举和来源契约 | 负向 validation 测试 |
| P1 | `outOfRangePolicy='error'` 被顶层吞掉 | error 策略重新抛出；降级策略使 analysis invalid | error/warn-clamp 测试 |
| P1 | nominal reference 缺失按 0% loss 放行 | 高速缺失时 fail-closed，loss=NaN，分类无效 | missing-reference 测试 |
| P1 | 气动加载失败静默 fallback | 输出 map/nominal load status 与失败消息 | provenance 测试 |
| P1 | synthetic map 与 nominal target 不一致 | 输出最大可达下压力和最小可能 loss；标记不可达 | target consistency 测试 |
| P1 | combined utilization 在多个模块定义不一致 | 统一为 superellipse radius；另存 constraint value | 3-4-5 数值 oracle |
| P1 | superellipse 允许 \(0<n<1\) 的非凸边界 | 输入契约收紧为有限标量 \(n\ge1\) | 非凸指数拒绝测试 |
| P1 | 暴露两个 proxy type 但实际同一实现 | 只允许已实现的 `friction_ellipse` | unsupported type 测试 |
| P1 | MATLAB 测试发现为 0 但可能假绿 | 新增可发现 `matlab.unittest` 套件与非零门禁入口 | `run_all_tests` |
| P1 | 轮胎后评估失败未同步清除分类与 map 状态 | 集中失效函数统一设置 `analysisReady/classificationValid/engineeringReady=false` 和 `mapClass=-1` | 压力、越域、接地丢失测试 |
| P1 | 畸形嵌套输入绕过校验，批处理 error row 二次崩溃 | 递归检查嵌套 struct shape；稳定单点/批量错误 schema 与阶段标记 | malformed single/batch 测试 |
| P2 | `analysisReady` 被错误等同于通过设计目标 | 改为数值/数据有效性；`feasible` 单独表示约束通过 | synthetic/unreachable target 测试 |
| P2 | error 结果 schema 与正常结果漂移 | 补齐 validity、provenance、load components 和 utilization 结构 | returnOnError schema 测试 |
| P2 | 无法还原用户真正提交的输入 | 增加 `inputsSubmitted`，保留 normalized/solved 输入 | input provenance 测试 |
| P2 | range 只算前后轴相关对角线但未说明 | 输出 `correlated_diagonal_front_rear` 与非 Cartesian 标志 | range metadata 测试 |
| P2 | `y>0` 向右但 `man.ay>0` 的工况语义未公开 | 明确 `man.ay>0` 为左转，输出 `ayTurn/ayCartesian/ayConvention` | 横向符号契约测试 |
| P2 | 气动轴/表缺少数值与严格单调校验 | validation 增加 grid/table schema 检查；允许显式 NaN 缺口走已打标的 fallback，但拒绝 Inf/全无有限值 | duplicate-grid/Inf-table 测试 |
| P2 | demo 生产入口依赖 `tests/` fixture | 将 synthetic demo case builder 移到 `config/` | demo smoke tests |
| P2 | 规则名 `FSC_FSG_common` 无来源边界 | 默认 profile 改为 `FSG_2026_v1.1`，分别记录 T2.2.1/T2.5.1；报告另行映射 FSC T3.1.1/T3.2.1，不再声称二者完全相同 | clause/provenance 测试 |

## 7. 剩余风险与下一阶段门禁

以下不是本轮可用少量补丁安全解决的问题，必须保持 `NOT READY`：

1. **簧上/簧下质量未分离**  
   姿态与载荷转移均使用 `veh.m`。需要至少增加 sprung mass、unsprung mass、各自 CG/roll-center 相关参数，并重新推导几何与弹性转移。

2. **direct load path 未与轮胎柔度共同反求姿态**  
   当前 ARB、roll-center、anti 直接路径在后处理恢复接地载荷，但不会通过轮胎压缩反馈到 \(q\)。应升级为角点自由度或 4×4 刚度消元，并以当前结果作为退化特例。

3. **真实气动数据缺失**  
   需要同一车辆配置、同一参考面积与坐标、明确 ride-height/pitch/roll/yaw 网格、CFD/风洞来源、网格/收敛/不确定度和 nominal reference。必须先解决当前 map/reference 量级冲突。

4. **真实轮胎数据缺失**  
   当前表是 synthetic proxy。需要同一轮胎、轮辋、胎压、温度、法向载荷、外倾角和路面条件的数据；若要研究胎压，压力必须成为显式表维度或有经验证的修正模型。

5. **轮胎力未与工况闭环**  
   `alpha/kappa` 由用户指定，不由 `ax/ay`、转向、横摆、轮速和驱制动力分配求解。不能用当前 balance 直接宣称车辆能实现给定加速度。

6. **range 不是独立不确定性包络**  
   现有 low/nominal/high 是前后轴相关对角线。若前后胎刚度不确定性独立，应运行 3×3 Cartesian envelope。

7. **稀疏/降维轮胎插值仍需专门设计**  
   singleton 轴、稀疏网格和 scattered convex-hull 外查询应使用有效 mask、降维插值和统一 finite 判据，不能把缺失单元填成零能力。

8. **瞬态边界**  
   当前没有 sprung/unsprung inertia、阻尼器速度、路面、轮跳、横摆/侧偏动态或 turn-in/exit 时序。准静态结果不能替代瞬态仿真。

9. **规则适用性**  
   已核验 FSG 2026 v1.1 与中国 2026 最终版。两者均出现驾驶员条件下的 30 mm 静态离地间隙和 \(\ge50\,mm\) 行程阈值，但 50 mm 项的措辞、测量项和附加要求不同；中国最终版未见 FSG 的独立 25 mm minimum-jounce 条款。当前代码默认采用 FSG profile；参加 FSCC/FSEC/FSAC 时必须显式选择中国规则，并把额外 25 mm 保留为项目目标而不是赛事规则。

## 8. 验证门禁

项目统一测试入口：

```matlab
cd('E:\JX Areo adaption\fs_platform_model');
addpath(genpath(pwd));
summary = run_all_tests();
```

入口先运行可发现的 `matlab.unittest` 套件，并在发现 0 项或任一失败时硬失败；随后逐项执行 56 个 legacy regression function。本轮最终证据为：

| 门禁 | 结果 |
|---|---|
| MATLAB R2025b Update 5 | 可发现测试 39/39；legacy regression 56/56；全部通过 |
| MATLAB R2026a Update 4 | 可发现测试 39/39；legacy regression 56/56；全部通过 |
| Code Analyzer（R2025b） | 112 个 `.m` 文件；active findings 为 4 条既有测试文件 `MSNU` info；另有代码内显式压制的 16 条 `AGROW` info；无 active error/warning |
| `git diff --check` | 通过；仅工作区既有 LF/CRLF 转换提示 |

上述双版本结果来自本轮对当前工作区的交互式完整运行，退出码均为 0；仓库尚未配置 CI，也未持久化 JUnit/XML/TRX/JSON/MAT 原始测试产物。预期的 out-of-range clamp、压力契约拒绝和 shock consistency warning 来自负向/警告路径测试，不计为失败。测试通过只证明当前软件契约与本文解析 oracle 一致，不替代真实参数和实车验证。

建议下一阶段只在以下条件全部满足后把状态从 `NOT READY` 升级：

- 目标赛事 profile 明确，且规则条款与项目内部保守目标分层；
- 气动 map 和 nominal reference 使用同一经过验证的数据源；
- 实测轮胎数据及压力/温度适用域明确；
- 4×4 角点柔度/直接路径模型通过退化、解析和对比测试；
- sprung/unsprung 质量与质心参数来自称重或 CAD/试验；
- 至少一个实车静态称重、斜台/横向载荷转移、制动俯仰和 ride-height 气动基准完成对比；
- 当前完整回归继续通过，且新增实测基准误差门槛通过。

## 9. 公开资料清单与证据属性

| 资料 | 来源/审查属性 | 本报告使用范围 | 适用边界 |
|---|---|---|---|
| [Formula Student Rules 2026 v1.1](https://www.formulastudent.de/fileadmin/user_upload/all/2026/rules/FS-Rules_2026_v1.1.pdf) | FSG 官方规范性规则 | T2.2.1 静态离地间隙；T2.5.1 usable travel、minimum jounce、悬架/减振器要求 | 仅对其适用赛事和版本构成规则依据；不能替代中国规则 |
| [2026 中国大学生方程式系列赛事规则（最终版）](https://img.sae-china.org/web/2026/04/2026%E4%B8%AD%E5%9B%BD%E5%A4%A7%E5%AD%A6%E7%94%9F%E6%96%B9%E7%A8%8B%E5%BC%8F%E7%B3%BB%E5%88%97%E8%B5%9B%E4%BA%8B%E8%A7%84%E5%88%99%EF%BC%88%E6%9C%80%E7%BB%88%E7%89%88%EF%BC%89.pdf) | 中国汽车工程学会官方规范性规则 | A3.3.5、T3.1.1、T3.2.1；FSCC/FSEC/FSAC 规则边界 | 独立适用；最终版未见独立 25 mm minimum-jounce 条款 |
| [Bucchi & Lenzo: *Analytical Derivation and Analysis of Vertical and Lateral Installation Ratios for Swing Axle, McPherson and Double Wishbone Suspension Architectures*](https://www.mdpi.com/2076-0825/11/8/229) | 同行评审论文 | installation ratio、虚功和局部刚度边界 | 不验证本车硬点、MR 数值或线性行程范围 |
| [Chalmers: *Compendium in Vehicle Motion Engineering*](https://research.chalmers.se/publication/532725/file/532725_Fulltext.pdf) | 高校课程 compendium；非同行评审论文 | 纵向/横向准静态载荷转移基础 | 作为教学性理论交叉核对，不替代车型参数验证 |
| [NASA Glenn: Dynamic Pressure](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/dynamic-pressure/) / [Drag Coefficient](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-coefficient/) | 美国政府官方技术说明 | \(\tfrac12\rho V_{rel}^2AC\) 的量纲和定义 | 只支持基础气动关系，不验证本车系数、参考面积或 map |
| [Altair: Anti-Dive/Lift](https://help.altair.com/2022/hwdesktop/hwx/topics/motionview/sdf_anti-dive_lift_and_brake_dive_lift_r.htm) / [Anti-Lift/Squat](https://help.altair.com/hwdesktop/hwx/topics/motionview/sdf_anti-lift_squat_and_acceleration_lift_squat_r.htm) | 厂商官方技术文档 | anti geometry 与纵向载荷路径概念 | 对产品定义/几何概念是一手资料；不验证项目代理百分比 |
| [Ghandriz et al.: *Computationally Efficient Nonlinear One- and Two-Track Models for Multitrailer Road Vehicles*](https://doi.org/10.1109/ACCESS.2020.3037035) | 同行评审论文 | \(n=2\) friction circle/ellipse combined-slip 形式 | 不支持任意 \(n\) 或本项目轮胎能力表 |
| [Van Gennip: *Vehicle Dynamic Modelling and Parameter Identification for an Autonomous Vehicle* (University of Waterloo, 2018)](https://dspacemainprd01.lib.uwaterloo.ca/server/api/core/bitstreams/9a00429e-8e84-4468-a3ef-b2e92c671e0d/content) | 高校学位论文 | friction ellipse、combined slip 和固定胎压试验背景 | 背景证据；不是本项目拒绝压力扫描的直接依据 |
| [MIT OCW: Precision Engineering Principles](https://ocw.mit.edu/courses/2-76-multi-scale-system-design-fall-2004/3aa5862a1724b75c3e4aa7a6fee6c511_reading_l3.pdf) | 高校公开课程材料 | 多自由度 stiffness/compliance 串并联原则 | 教学性基础关系，不验证车辆参数 |
| [MIT OCW: Two Springs in Series](https://ocw.mit.edu/courses/1-105-solid-mechanics-laboratory-fall-2003/0f895868598a52276cafb4875f9c277b_exp3_03.pdf) / [Altair: Wheel and Ride Rate](https://help.altair.com/hwdesktop/hwx/topics/motionview/sdf_wheel_rate_ride_rate_and_hop_rate_r.htm) | 高校课程材料 / 厂商官方技术文档 | 串联柔度求和 | 只支持理想线性局部关系 |
| [OptimumG/Racecar Engineering: *The No Way Transfer, Part 2*](https://optimumg.com/wp-content/uploads/2021/10/OptimumG-Septepmber-2021.pdf) | 专业二手技术文章；非同行评审 | 几何/弹性载荷转移路径分解概念 | 仅作概念性交叉核对 |
| [MathWorks: `griddedInterpolant`](https://www.mathworks.com/help/matlab/ref/griddedinterpolant.html) | 软件厂商官方 API 文档 | MATLAB 插值网格契约 | 只对 API 行为具有一手权威性，不验证物理模型 |

这些属性说明“资料能支持什么”，不表示仓库参数已由资料验证。公式来源成立、代码实现一致和具体赛车参数正确是三个不同层级。
