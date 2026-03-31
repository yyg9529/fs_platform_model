# FS Platform Model 交接总览（V1.0 -> V1.0.1 -> V1.0.2 -> V1.0.3 -> V1.0.3a）

## 文档用途
本文件用于 V1.0.3a 交接，作为后续线程继续优化时的单一事实来源。
重点记录：本次到底改了什么、哪些字段语义发生了正式变化、哪些兼容字段仍保留。

## 项目路径
- 项目根目录：`E:\JX Areo adaption\fs_platform_model`
- 本交接文档目录：`E:\JX Areo adaption\fs_platform_model\docs`

## 版本连续性（必须保持）
1. `V1.0`
- 建立三自由度准静态平台模型：`q = [z; theta; phi]`
- 建立 heave / pitch / roll 与气动姿态耦合主链

2. `V1.0.1`
- 停用 bump/droop 附加力，不再作为主平衡方程力项
- 引入 shock eye-to-eye 输入：`shockLenExtended / shockLenCompressed / shockLenStatic`
- wheel/shock 行程改为后处理判据

3. `V1.0.2`
- 统一 `keq=kw` 语义（当时仍不显式处理轮胎柔度）
- 分离 `converged` 与 `feasible`
- 气动插值开始输出可追踪标志

4. `V1.0.3`
- 新增 `tire.mode = off/fixed/range`
- 位移语义拆分为 `deltaGround / deltaSuspWheel / deltaTire / shockStroke`
- 新增 `rules` / `targets` / `feasible` 分层判据
- `run_batch` 扩展为可直接筛方案的 summary

5. `V1.0.3a`（当前）
- 正式拆分 `static clearance` 与 `dynamic clearance`
- `rules` 层只看静态离地高
- `targets` 层只看动态离地高
- 正式引入 `effective travel` 进入 rule check
- 修正 `tire.mode='range'` 顶层 `results.inputs` 语义
- `validation.warnings` 在 `warnOnDeprecatedInput=true` 时通过真实 `warning(...)` 发射
- `run_batch` summary 增加 static/dynamic clearance 与 effective travel 字段

## 主接口连续性
以下接口保持不变：
- `run_case(caseDef, options)`
- `run_batch(caseArray, options)`
- `caseDef` 顶层结构
- `results` 顶层结构
- eye-to-eye 输入体系

新增但不破坏连续性的输出：
- `results.inputsRaw`
- `results.inputsNominal`（range 模式）
- `results.clearance.hStatic* / hDynamic*`
- `results.rules.minEffectiveJounce / minEffectiveTotalTravel`

## 当前统一物理语义（V1.0.3a）

### 状态与符号
- 状态：`q = [z; theta; phi]`
- `z > 0`：车身下沉
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾

### 刚度链路
- `mr = spring / wheel`
- `kw = ks * mr^2`（悬架侧轮端刚度）
- `keq` 由 `tire.mode` 决定：
  - `off`：`keq = kw`
  - `fixed/range`：`keq = kw * kt / (kw + kt)`

### 位移语义
- `Fmain = keq .* deltaGeom`
- `deltaSuspWheel = Fmain ./ kw`
- `deltaTire = Fmain ./ kt`（`off` 模式为 0）
- `deltaGround = deltaSuspWheel + deltaTire`
- `shockStroke = mr .* deltaSuspWheel`

### 一致性检查
- `deltaReconError = deltaGroundGeom - (deltaSuspWheel + deltaTire)`
- 输出到：`results.debug.validation.deltaReconError`
- 超容差会触发 warning 并置 `results.flags.deltaReconWarning=true`

## static / dynamic clearance 正式定义

### 静态离地高
- 来源：`caseDef.ref.hClear0`
- 输出：
  - `results.clearance.hStaticAll`
  - `results.clearance.hStaticMin`
  - `results.clearance.hStaticMinName`

### 动态离地高
- 来源：`hClear0 - (z + x*theta + y*phi)`
- 输出：
  - `results.clearance.hDynamicAll`
  - `results.clearance.hDynamicMin`
  - `results.clearance.hDynamicMinName`

### 兼容字段
以下字段继续保留，但统一指向 dynamic clearance：
- `results.clearance.hAll`
- `results.clearance.hMin`
- `results.clearance.hMinName`
- `results.platform.clearanceValues`
- `results.platform.hMin`

## rules / targets / feasible 逻辑（V1.0.3a）

### rules 层
只看：
1. `staticGroundClearancePass`：由 `hStaticMin` 判定
2. `usableWheelTravelPass`：由 `minEffectiveTotalTravel` 判定
3. `minJouncePass`：由 `minEffectiveJounce` 判定

### effective travel 定义
- `wheelJounceFromShock = shockCompAvail ./ mr`
- `wheelDroopFromShock = shockReboundAvail ./ mr`
- `effectiveJounce = min(jounceMax, wheelJounceFromShock)`
- `effectiveDroop = min(droopMax, wheelDroopFromShock)`
- `effectiveTotalTravel = effectiveJounce + effectiveDroop`

输出：
- `results.corners.effectiveJounce / effectiveDroop / effectiveTotalTravel`
- `results.rules.minEffectiveJounce`
- `results.rules.minEffectiveTotalTravel`

### targets 层
只看：
1. `dynamicClearancePass`：由 `hDynamicMin` 判定
2. `pitchPass`
3. `rollPass`
4. `aeroLossPass`
5. `frontShareMigrationPass`

### feasible 层
仍保持分层：
- `converged`
- `rulePass`
- `designPass`
- `feasible`

推荐 gate：
```matlab
feasible = converged ...
    && rulePass ...
    && designPass ...
    && (~strictTravelViolation || (~travelViolationAny && ~clearanceViolation));
```

## range 模式输出结构（V1.0.3a 修正点）
当 `tire.mode='range'` 时：
- 顶层 `results.inputs`
  - 保留 primary 场景的预处理结构（默认 nominal）
- 顶层 `results.inputsRaw`
  - 保留 range 原始输入（未预处理）
- 顶层 `results.inputsNominal`
  - 保留 nominal 场景预处理输入
- 子结果：
  - `results.range.low`
  - `results.range.nominal`
  - `results.range.high`
- 区间汇总：`results.range.band`
  - `hStaticMin`
  - `hDynamicMin`
  - `effectiveTotalTravel`
  - `staticGroundClearancePass`
  - `dynamicClearancePass`
  - `lossPct`
  - `frontShareMigrationPct`
  - `feasible / rulePass / designPass`

## validation warnings 机制（V1.0.3a 新增）
当 `caseDef.solver.warnOnDeprecatedInput = true` 时：
- `validate_case_struct` 产生的 `validation.warnings` 会被 `run_case` 循环调用 `warning(...)`
- 不再只是静态挂在 `caseDef.validation.warnings`
- 典型 warning 来源：
  - deprecated 输入字段
  - auto-filled 缺失字段
  - shock↔wheel 一致性提示

## run_batch 当前 summary 字段（V1.0.3a）
至少包含：
- `Converged`
- `RulePass`
- `DesignPass`
- `Feasible`
- `hStaticMin`, `hStaticMin_mm`
- `hDynamicMin`, `hDynamicMin_mm`
- `hMin`, `hMin_mm`（兼容 dynamic）
- `StaticGroundClearancePass`
- `DynamicClearancePass`
- `EffectiveJounce`, `EffectiveJounce_mm`
- `EffectiveTotalTravel`, `EffectiveTotalTravel_mm`
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

## deprecated 策略（仍保留兼容）
以下字段保留读取兼容，但不再进入主求解：
1. `sus.kt`
2. `sus.kBump / bumpGap / kDroop / droopGap`
3. `solver.useNonlinearCorner`
4. `corner.Fbump / Fdroop / bumpOn / droopOn`

策略要求：
- 传入时给 warning
- 不 silently 参与主求解

## 当前测试状态（V1.0.3a）
已新增并通过：
1. `test_static_dynamic_clearance_split`
2. `test_static_clearance_rule_uses_static_values`
3. `test_effective_travel_rule_check`
4. `test_effective_jounce_rule_check`
5. `test_range_results_inputs_consistency`
6. `test_validation_warnings_emit`
7. `test_run_batch_summary_fields_v103a`

此前 V1.0 / V1.0.3 关键测试继续保留：
- `test_zero_speed_zero_load`
- `test_static_symmetry`
- `test_roll_gradient_linear_case`
- `test_pitch_under_braking`
- `test_delta_decomposition_consistency`
- `test_shock_stroke_from_susp_wheel`
- `test_rule_checks`
- `test_shock_wheel_consistency_warning`
- `test_tire_mode_off_fixed_range`
- `test_aero_map_flags`

## 最近一次本地验证（2026-03-20）
1. 新增 V1.0.3a 关键测试：全部通过
2. 注意：MATLAB 在沙箱内启动会报 `File system inconsistency`，需要在沙箱外运行
3. warning 文本在当前终端编码下显示有乱码，但 MATLAB 逻辑与测试结果正常

## 下一步建议
1. 若继续做 V1.0.4，可把 `results.range.band` 扩展到 percentile / worst-case 聚合
2. 若继续做 V1.5，可在不回退主链的前提下加入真实 bump stop / top-out 曲线
3. 若继续做方案筛选工具，可在 `run_batch` 基础上直接叠加 Pareto 或规则过滤脚本
