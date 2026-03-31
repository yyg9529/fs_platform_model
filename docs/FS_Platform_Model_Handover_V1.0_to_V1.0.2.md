# FS Platform Model 交接总览（V1.0 → V1.0.1 → V1.0.2）

## 文档用途
本文件用于跨线程连续开发的“单一事实来源（single source of truth）”。
后续线程可直接读取本文件，快速了解项目背景、版本演进、当前物理语义、接口、测试状态与遗留注意事项。

## 项目路径
- 项目根目录：`E:\JX Areo adaption\fs_platform_model`
- 本交接文档目录：`E:\JX Areo adaption\fs_platform_model\docs`

## 版本演进关系（必须保持连续）
1. V1.0（已完成）
- 建立三自由度准静态平台模型：`q = [z; theta; phi]`
- 已实现 heave/pitch/roll 求解
- 已实现气动-姿态耦合
- 已实现 `run_case` / `run_batch` / `demo_case_2026` / tests / visualization
- 已形成完整工程结构（main/config/core/aero/utils/visualization/tests/data）

2. V1.0.1（已完成）
- 删除 bump/droop 附加受力模型（不进入平衡方程）
- 引入 shock eye-to-eye 输入：
  - `sus.shockLenExtended`
  - `sus.shockLenCompressed`
  - `sus.shockLenStatic`
- 支持标量或四角点数组输入（顺序固定 `[FL FR RL RR]`）
- 将 wheel/shock 行程超限转为后处理约束判据

3. V1.0.2（当前）
- 在 V1.0.1 基础上继续统一物理语义
- 主平衡刚度统一为：`keq = kw`
- 彻底移除 `kt` 参与主平衡
- `deltaWheel` 明确为“纯悬架轮端位移”
- 正式分离 `converged` 与 `feasible`
- 气动查表新增可追踪标记：`mapClamped`、`interpFallbackUsed`

## 当前统一物理定义（V1.0.2）

### 状态与符号
- 状态：`q = [z; theta; phi]`
- `z > 0`：车身下沉
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾
- `ay > 0`：左转
- `ax < 0`：制动
- `ax > 0`：加速

### 角点与刚度
- `mr` 定义：`spring / wheel`
- `kw = ks * mr^2`
- **V1.0.2 主平衡刚度：`keq = kw`**
- **禁止**继续使用：`keq = kw*kt/(kw+kt)`

### 位移与力
- `delta_i`（或 `deltaWheel`）= 纯悬架轮端位移
- 角点主力：`DeltaF_i = kw_i * delta_i`
- `shockStroke_i = mr_i * delta_i`

### shock 派生量
- `shockStrokeTotal = shockLenExtended - shockLenCompressed`
- `shockStrokeStaticUsed = shockLenExtended - shockLenStatic`
- `shockCompAvail = shockLenStatic - shockLenCompressed`
- `shockReboundAvail = shockLenExtended - shockLenStatic`
- `shockCurrentUsed = shockStrokeStaticUsed + shockStroke`

## 保持不变的工程约束
1. 目录结构不变（main/config/core/aero/utils/visualization/tests/data）
2. 单入口不变：`run_case(caseDef, options)`
3. 批处理入口不变：`run_batch(caseArray, options)`
4. `build_case_2025_baseline` 与 `build_case_2026_target` 持续可用
5. 测试体系保留并扩展（不是推倒重写）

## 当前输入结构要点（caseDef）
顶层字段保留：
- `meta`, `veh`, `sus`, `longi`, `aero`, `ref`, `man`, `solver`

`sus` 重点字段：
- 主字段：`ks`, `mr`, `kw`, `jounceMax`, `droopMax`, `kArbF`, `kArbR`
- shock 三长度：`shockLenExtended`, `shockLenCompressed`, `shockLenStatic`
- 兼容字段：`kt`（deprecated，仅兼容保留）
- 兼容旧字段：`kBump`, `bumpGap`, `kDroop`, `droopGap`（deprecated，忽略）

## 当前输出结构要点（results）

### state
- `z`, `theta`, `phi`（含 `theta_deg`, `phi_deg`）

### aero
- `hf`, `hr`, `Cz`, `Cd`, `Fz`, `Drag`
- `frontShare`, `rearShare`
- `lossPct`, `balanceMigrationPct`
- 兼容：`frontShareMigrationPct`

### corners
- `deltaWheel`
- `wheelJounce`, `wheelDroop`
- `wheelJounceUsagePct`, `wheelDroopUsagePct`
- `shockStroke`, `shockCurrentUsed`
- `shockCompMargin`, `shockReboundMargin`
- `shockPositionPct`, `shockDynamicStrokePct`
- `shockCompUsagePct`, `shockReboundUsagePct`

### clearance（V1.0.2 正式层级）
- `hAll`, `hMin`, `hMinName`

### flags
- `converged`
- `feasible`
- `wheelJounceViolationAny`
- `wheelDroopViolationAny`
- `shockCompViolationAny`
- `shockReboundViolationAny`
- `travelViolationAny`
- `clearanceViolation`
- `mapClamped`
- `interpFallbackUsed`
- `badInput`

### debug
- `iterHistory`, `residualHistory`, `lastResidual`, `message`
- `solverUsed`
- `mapClampInfo`

## converged 与 feasible 的正式定义
- `converged`：仅表示数值求解成功
- `feasible`：表示工程可接受

当前实现等价为：
`feasible = converged && ~wheelJounceViolationAny && ~wheelDroopViolationAny && ~shockCompViolationAny && ~shockReboundViolationAny && ~clearanceViolation`

## run_batch 汇总（已扩充）
当前 `run_batch` summaryTable 已支持至少以下字段：
- Name
- Converged
- Feasible
- Z_mm
- Theta_deg
- Phi_deg
- Hf_mm
- Hr_mm
- AeroLoad_N
- Drag_N
- LossPct
- FrontShare
- FrontShareMigrationPct
- MinClearance_mm
- TravelViolation
- ShockCompViolation
- ShockReboundViolation
- ClearanceViolation
- MaxWheelJounceUsagePct
- MaxWheelDroopUsagePct
- MaxShockCompUsagePct
- MaxShockReboundUsagePct
- MinShockCompMargin_mm
- MinShockReboundMargin_mm

## 气动插值机制（V1.0.2）
- 查表 query 超界会 clamp 到边界
- 若线性插值失败或产生非有限值，会切换 nearest fallback
- 两类行为均会留痕：
  - `results.flags.mapClamped`
  - `results.flags.interpFallbackUsed`
  - `results.debug.mapClampInfo`

## 当前测试体系（保留并扩展）

### 基础测试（保留）
1. `test_zero_speed_zero_load`
2. `test_static_symmetry`
3. `test_roll_gradient_linear_case`
4. `test_pitch_under_braking`

### V1.0.2 重点测试（新增/重命名）
5. `test_shock_length_derived_metrics`
6. `test_shock_comp_violation`
7. `test_shock_rebound_violation`
8. `test_wheel_shock_consistency`
9. `test_feasible_flag`

### 旧测试名兼容入口（保留转调）
- `test_shock_static_position` -> `test_shock_length_derived_metrics`
- `test_shock_compression_violation` -> `test_shock_comp_violation`
- `test_wheel_vs_shock_consistency` -> `test_wheel_shock_consistency`

## 最近一次实测状态（已通过）
1. `checkcode`：`TOTAL_CHECKCODE_MESSAGES=0`
2. `demo_case_2026`：通过
3. 9项必测：全部通过
4. `run_batch` 汇总字段验证：通过
5. `results` 结构字段核验：通过

## demo 数值变化说明（V1.0.2 vs V1.0.1）
- V1.0.2 下 demo 的 `z/theta/phi` 相较 V1.0.1 略减小（刚度提高）
- 根因：主平衡从 `keq = kw*kt/(kw+kt)` 改为 `keq = kw`

## 兼容保留项清单（不参与当前主求解）
1. `sus.kt`（deprecated）
2. `sus.kBump`, `sus.bumpGap`, `sus.kDroop`, `sus.droopGap`（deprecated）
3. 结果结构兼容字段：`results.platform`、`results.aero.frontShareMigrationPct`

## 当前模型一句话定义
`fs_platform_model` 当前版本是：
**基于 V1.0 与 V1.0.1 连续演化得到的 V1.0.2 悬架-气动准静态平台模型（bump/droop 停用，kt 不参与主平衡，feasible 与 converged 分离）。**

## 建议后续（V1.5方向）
1. 在保持 V1.0.2 主结构不变的前提下，引入真实 bump stop/top-out 非线性曲线
2. 继续完善 map 数据质量控制（网格覆盖、异常点处理、插值鲁棒性）
3. 批量筛选增加可行域优先级评分

## 文档校验记录（本次）
本文件已对以下内容逐项复核后写入：
1. 版本继承关系（V1.0 -> V1.0.1 -> V1.0.2）
2. keq=kw 与 kt 退役语义
3. bump/droop 停用状态
4. shock 长度体系与派生公式
5. feasible 与 converged 的分离定义
6. run_batch 扩展字段
7. 测试清单与通过状态
8. 兼容保留字段与用途说明
