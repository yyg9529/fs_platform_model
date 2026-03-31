# FS Platform Model 交接总览（V1.0 -> V1.0.1 -> V1.0.2 -> V1.0.3）

## 文档用途
本文件用于跨线程连续开发的“单一事实来源（single source of truth）”。
后续线程可直接读取本文件，快速了解项目背景、版本演进、当前物理语义、接口、测试状态与遗留注意事项。

## 项目路径
- 项目根目录：`E:\JX Areo adaption\fs_platform_model`
- 本交接文档目录：`E:\JX Areo adaption\fs_platform_model\docs`

## 版本演进关系（必须保持连续）
1. V1.0（已完成）
- 建立三自由度准静态平台模型：`q = [z; theta; phi]`
- 实现 heave/pitch/roll 与气动-姿态耦合主链
- 形成完整工程结构（main/config/core/aero/utils/visualization/tests/data）

2. V1.0.1（已完成）
- 停用 bump/droop 附加受力模型（不进入主平衡方程）
- 引入 shock eye-to-eye 输入：
  - `sus.shockLenExtended`
  - `sus.shockLenCompressed`
  - `sus.shockLenStatic`
- wheel/shock 行程约束转为后处理判据

3. V1.0.2（已完成）
- 主平衡刚度统一：`keq = kw`
- `kt` 退出主平衡，仅兼容保留
- `deltaWheel` 语义明确为纯悬架轮端位移
- 正式分离 `converged` 与 `feasible`
- 气动查表新增可追踪标记：`mapClamped`、`interpFallbackUsed`

4. V1.0.3（当前）
- 新增轮胎柔度模式：`tire.mode = off/fixed/range`
- 位移语义彻底拆分：`deltaGround/deltaSuspWheel/deltaTire/shockStroke`
- 新增赛规层判据：`results.rules.*`
- 新增工程目标层判据：`results.targets.*`
- 正式分层：`converged/rulePass/designPass/feasible`
- 气动插值透明化升级（细粒度 clamp + fallback 策略）
- `run_batch` 扩展为可直接筛选方案的 summary

## 当前统一物理定义（V1.0.3）

### 状态与符号
- 状态：`q = [z; theta; phi]`
- `z > 0`：车身下沉
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾
- `ay > 0`：左转
- `ax < 0`：制动
- `ax > 0`：加速

### 角点刚度链定义
- `mr` 定义：`spring / wheel`
- `kw = ks * mr^2`（悬架侧轮端刚度）
- `keq` 由 `tire.mode` 决定：
  - `off`：`keq = kw`
  - `fixed/range`：`keq = kw*kt/(kw+kt)`

### 位移与力（V1.0.3 正式语义）
- `Fmain = keq .* deltaGeom`
- `deltaSuspWheel = Fmain ./ kw`
- `deltaTire = Fmain ./ kt`（仅 `tire.mode ~= off` 有效）
- `deltaGround = deltaSuspWheel + deltaTire`
- `shockStroke = mr .* deltaSuspWheel`

### 数值一致性检查
- `deltaReconError = deltaGroundGeom - (deltaSuspWheel + deltaTire)`
- 写入：`results.debug.validation.deltaReconError`
- 超容差会给 warning，并置 `results.flags.deltaReconWarning=true`

### shock 派生量（沿用 V1.0.1/V1.0.2）
- `shockStrokeTotal = shockLenExtended - shockLenCompressed`
- `shockStrokeStaticUsed = shockLenExtended - shockLenStatic`
- `shockCompAvail = shockLenStatic - shockLenCompressed`
- `shockReboundAvail = shockLenExtended - shockLenStatic`
- `shockCurrentUsed = shockStrokeStaticUsed + shockStroke`

## 当前输入结构要点（caseDef）
顶层字段保持统一：
- `meta`, `veh`, `sus`, `tire`, `rules`, `targets`, `longi`, `aero`, `ref`, `man`, `solver`

### tire（V1.0.3 新增）
- `mode`: `'off' | 'fixed' | 'range'`
- `ktFront`, `ktRear`
- `ktFrontRange`, `ktRearRange`
- `notes`

### rules（V1.0.3 新增）
- `ruleSet`
- `minStaticGroundClearance`
- `minUsableWheelTravelTotal`
- `minJounce`
- `enforceRules`

### targets（V1.0.3 新增）
- `minDynamicClearance`
- `maxPitchDeg`
- `maxRollDeg`
- `maxAeroLossPct`
- `maxFrontShareMigrationPct`
- `enforceTargets`

### solver（V1.0.3 新增/生效项）
- `strictTravelViolation`（已正式接入 feasible）
- `errorOnInterpFailure`
- `rangeUseNominalAsPrimary`
- `warnOnDeprecatedInput`
- `useNonlinearCorner`（deprecated，仅兼容）

## 当前输出结构要点（results）

### state
- `z`, `theta`, `phi`（含 `theta_deg`, `phi_deg`）

### aero
- `hf`, `hr`, `Cz`, `Cd`, `Fz`, `Drag`
- `frontShare`, `rearShare`, `lossPct`, `balanceMigrationPct`
- 兼容：`frontShareMigrationPct`
- 新增标记：
  - `mapClampedAny`
  - `hfClamped`, `hrClamped`, `phiClamped`, `betaClamped`
  - `interpFallbackUsed`

### tire（V1.0.3 新增层级）
- `mode`
- `ktUsed`
- `ktCaseLabel`
- `ktBand`
- `tireComplianceIgnored`
- `groundMetricConfidence`

### corners
- `deltaGround`
- `deltaSuspWheel`
- `deltaTire`
- `shockStroke`
- `shockPositionPct`
- `shockStaticPositionPct`
- `shockBiasFromMidPct`
- `shockDynamicStrokePct`
- 兼容：`deltaWheel`（= `deltaSuspWheel`）、`delta`

### clearance
- `hAll`, `hMin`, `hMinName`

### rules（V1.0.3 新增）
- `staticGroundClearancePass`
- `usableWheelTravelPass`
- `minJouncePass`
- `rulePassRaw`, `rulePass`
- `staticGroundClearanceMargin`
- `usableWheelTravelMargin`
- `jounceMargin`

### targets（V1.0.3 新增）
- `dynamicClearancePass`
- `pitchPass`
- `rollPass`
- `aeroLossPass`
- `frontShareMigrationPass`
- `designPassRaw`, `designPass`
- 对应 margin 字段

### flags（四层判定）
- `converged`
- `rulePass`
- `designPass`
- `feasible`
- `travelViolationAny`
- `clearanceViolation`
- `tireComplianceIgnored`
- `groundReferencedLowConfidence`
- `shockWheelConsistencyWarning`
- `deltaReconWarning`
- `mapClampedAny`
- `interpFallbackUsed`
- 兼容：`mapClamped`

### debug
- `iterHistory`, `residualHistory`, `lastResidual`, `message`, `solverUsed`
- `mapClampInfo`
- `validation.deltaReconError`
- `validation.wheelJounceFromShock`
- `validation.wheelDroopFromShock`

## run_case 语义（V1.0.3）
- 主入口保持不变：`run_case(caseDef, options)`
- `tire.mode='range'` 时自动执行 low/nominal/high 三场景
- 输出：
  - 主结果（默认 nominal，受 `solver.rangeUseNominalAsPrimary` 控制）
  - `results.range.low`
  - `results.range.nominal`
  - `results.range.high`
  - `results.range.band`（汇总区间）

## run_batch 汇总（V1.0.3 已扩充）
`summaryTable` 当前包含至少：
- `Converged`
- `RulePass`
- `DesignPass`
- `Feasible`
- `TravelViolation`
- `ClearanceViolation`
- `LossPct`
- `FrontShareMigrationPct`
- `MaxShockCompUsagePct`
- `MaxShockReboundUsagePct`
- `MaxWheelJounceUsagePct`
- `MaxWheelDroopUsagePct`
- `MinShockCompMargin_mm`
- `MinShockReboundMargin_mm`
- `ShockStaticPositionPct`
- `ShockBiasFromMidPct`
- `TireMode`
- `KtCase`
- `KtBand`
- `hMin`（及 `hMin_mm`）

## 气动插值机制（V1.0.3）
- 查询超界会 clamp，并输出细粒度 clamp 标记
- 线性插值失败或非有限值：
  - `solver.errorOnInterpFailure = true`：直接报错
  - `solver.errorOnInterpFailure = false`：nearest fallback 并置 `interpFallbackUsed=true`
- 不允许“静默失败且无标记”

## deprecated 兼容策略（短期）
以下字段保留读取兼容，但不再进入主求解：
1. `sus.kt`（建议迁移到 `tire.*`）
2. `sus.kBump`, `sus.bumpGap`, `sus.kDroop`, `sus.droopGap`
3. `solver.useNonlinearCorner`
4. `corner.Fbump/Fdroop/bumpOn/droopOn`（占位兼容）

策略要求：
- 传入时给 warning
- 不 silently 参与主力计算

## 当前测试体系状态（V1.0.3）

### 保留并通过的旧基础测试
1. `test_zero_speed_zero_load`
2. `test_static_symmetry`
3. `test_roll_gradient_linear_case`
4. `test_pitch_under_braking`

### 新增并通过的 V1.0.3 测试
5. `test_delta_decomposition_consistency`
6. `test_shock_stroke_from_susp_wheel`
7. `test_rule_checks`
8. `test_shock_wheel_consistency_warning`
9. `test_tire_mode_off_fixed_range`
10. `test_aero_map_flags`

### V1.0.2 关键测试继续通过
11. `test_shock_length_derived_metrics`
12. `test_shock_comp_violation`
13. `test_shock_rebound_violation`
14. `test_wheel_shock_consistency`
15. `test_feasible_flag`

### 兼容旧测试名入口（保留转调）
- `test_shock_static_position` -> `test_shock_length_derived_metrics`
- `test_shock_compression_violation` -> `test_shock_comp_violation`
- `test_wheel_vs_shock_consistency` -> `test_wheel_shock_consistency`

## 最近一次实测状态（本次）
1. 15 项选定测试：全部通过（含旧基础 + V1.0.3 新增）
2. `checkcode`：`TOTAL_CHECKCODE_MESSAGES=0`
3. 气动插值标记测试已覆盖 clamp 与 fallback 两条路径
4. 说明：MATLAB 在一次完整测试后退出阶段出现环境级 `std::terminate()`，但所有测试已在退出前 PASS，属于运行环境退出问题，不是模型逻辑回归失败

## 与 V1.0.2 的最关键差异总结
1. `kt` 不再是“要么删掉要么精确已知”的二选一，而是正式模式化为 `off/fixed/range`
2. 位移语义从“单一 delta”升级为 ground/susp/tire/shock 四层分解
3. 可行性不再只看 `converged + travel`，而是引入 `rulePass` 与 `designPass`
4. range 模式可直接输出方案区间，避免“单点假精确”
5. batch 输出具备直接筛 spring/MR/ARB/static position 方案的实用性

## 建议后续（V1.0.4 / V1.5 方向）
1. 在不回退主链前提下，引入真实 bump stop/top-out 非线性曲线（后处理或分段刚度）
2. `range` 模式扩展为可选统计输出（min/max/percentile）
3. 规则库扩展为多 ruleSet（如 FSC/FSG 年份差异模板）
4. 将 `results.range.band` 与可视化联动（可行域热图/窗口图）

## 文档校验记录（本次）
本文件已按当前代码逐项复核：
1. 新增 `tire/rules/targets` 顶层输入
2. `keq` 模式化处理（off/fixed/range）
3. 位移分解与 `shockStroke` 来源语义
4. rules/targets 判据层与四层可行性逻辑
5. 气动插值 clamp/fallback 可追踪机制
6. run_case range 输出结构
7. run_batch summary 扩展字段
8. deprecated 兼容与 warning 策略
9. 测试清单与通过状态
