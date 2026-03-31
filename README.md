# E40Gen3Suspension｜悬架-气动联合参数化模型（MATLAB）

## 版本定位
本项目是连续升级，不是重建工程。
当前版本为 `V1.0.4`，它仍然是：
- 三自由度准静态悬架-气动平台模型
- 状态定义 `q = [z; theta; phi]`
- 单点主入口 `results = run_case(caseDef, options)`
- 批量入口 `batchOut = run_batch(caseArray, options)`

`V1.0.4` 的定位不是进入 `V1.5` 或 `V2.0`，而是在 `V1.0.3a` 基础上补齐两层高价值增强：
1. 前后弹簧二维扫参的 pass/fail map
2. 基于准静态 dynamic clearance 的 bump-adjusted scrape robustness map

## 版本演化关系
1. `V1.0`
- 建立三自由度准静态平台模型（heave / pitch / roll）与气动耦合主链
- 输出动态离地高、姿态、气动载荷、角点载荷与基础可视化

2. `V1.0.1`
- 停用 bump / droop 附加力，不再作为主平衡方程的力项
- shock eye-to-eye 三长度成为正式输入
- wheel / shock 行程限制转为后处理约束与 violation flag

3. `V1.0.2`
- 明确 `converged` 与 `feasible` 分层
- 保持 `keq=kw` 的原有框架语义

4. `V1.0.3`
- 引入 `tire.mode = off / fixed / range`
- 重构 wheel / tire / shock 位移语义
- 引入 `rules / targets / feasible` 分层判定
- 扩展 `run_batch` 以支持工程筛选

5. `V1.0.3a`
- 正式拆分 `static clearance` 与 `dynamic clearance`
- `rules` 层只看静态离地高 + effective travel
- `targets` 层只看动态离地高
- 修正 range 模式的 `results.inputs / inputsRaw / inputsNominal`
- `validation.warnings` 可真实发射为 `warning(...)`

6. `V1.0.4`（当前）
- 新增 spring sweep case 生成、批处理与四色分类 map
- 新增 `aeroPlatformPass / scrapePassQuasiStatic / scrapePassBumpAdjusted`
- 新增基于 clearance 点位置的 `bumpAdjust.reserveFront / reserveRear` 保守扣减
- 新增 quasi-static 与 bump-adjusted 两套 scrape robustness map

7. `V1.0.4` 进入 `V1.5` 前的接口清洁修订
- 标准 case 显式补齐当前活跃输入字段，不再依赖 autofill warning 才成立
- 标准轮胎输入正式统一到 `tire.mode / ktFront / ktRear / ktFrontRange / ktRearRange`
- `sus.kt` 仅保留旧 case 兼容路径，不再出现在 baseline / target 正式输入中
- baseline / target / demo 正常运行时不应再出现 autofill / `sus.kt` deprecated warning

## 明确边界
`V1.0.4` 仍然不是：
- 完整瞬态 ride / bump 动力学模型
- `V1.5` 的 tire load sensitivity / grip proxy 平台
- `V2.0` 的 transient bicycle / turn-in / exit balance 模型

本版本 bump 功能只用于：
- 在准静态 dynamic clearance 结果上叠加保守附加扣减
- 做 scrape robustness screening

它不做：
- 新状态自由度
- sprung / unsprung 动态方程
- damper velocity 模型
- road profile / axle phase lag 求解

## 核心物理定义
### 状态与符号
- `q = [z; theta; phi]`
- `z > 0`：车身下沉
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾

### 刚度链路
- `mr = spring / wheel`
- `kw = ks * mr^2`：悬架侧轮端刚度
- `keq` 由 `tire.mode` 决定：
  - `off`：`keq = kw`
  - `fixed / range`：`keq = kw * kt / (kw + kt)`

### 位移语义
- `deltaSuspWheel = Fmain ./ kw`
- `deltaTire = Fmain ./ kt`（`tire.mode='off'` 时置零）
- `deltaGround = deltaSuspWheel + deltaTire`
- `shockStroke = mr .* deltaSuspWheel`

### static / dynamic clearance
- `hStaticAll / hStaticMin / hStaticMinName`：静态离地高
- `hDynamicAll / hDynamicMin / hDynamicMinName`：准静态动态离地高
- 兼容字段 `hAll / hMin / hMinName` 继续指向 dynamic clearance

### effective travel
- `wheelJounceFromShock = shockCompAvail ./ mr`
- `wheelDroopFromShock  = shockReboundAvail ./ mr`
- `effectiveJounce = min(jounceMax, wheelJounceFromShock)`
- `effectiveDroop  = min(droopMax,  wheelDroopFromShock)`
- `effectiveTotalTravel = effectiveJounce + effectiveDroop`

## tire.mode
顶层输入：`caseDef.tire`
- `mode`: `'off' | 'fixed' | 'range'`
- `ktFront`, `ktRear`
- `ktFrontRange`, `ktRearRange`
- `notes`

行为：
- `off`：只看悬架侧趋势，`results.flags.tireComplianceIgnored=true`
- `fixed`：给定单点轮胎刚度
- `range`：自动求解 `low / nominal / high` 三场景，并输出 `results.range.*`

当前正式接口约定：
- 标准 case 应显式使用 `tire.*`
- `sus.kt` 只保留 backward compatibility，不再作为正式案例输入

## V1.0.4 新增输入：bumpAdjust
顶层输入新增：`caseDef.bumpAdjust`
- `enable`
- `reserveFront`
- `reserveRear`
- `notes`

说明：
- 单位一律为 `m`
- `reserveFront / reserveRear` 可为前后分开的标量
- 若只给一侧，程序会自动扩展为前后同值
- 默认值为 `0`，默认不影响 V1.0.3a 的既有单点结果

## 判据层与 V1.0.4 新增 pass 定义
### rules 层
只看：
- `staticGroundClearancePass`
- `usableWheelTravelPass`
- `minJouncePass`

### targets 层
只看：
- `dynamicClearancePass`
- `pitchPass`
- `rollPass`
- `aeroLossPass`
- `frontShareMigrationPass`

### aeroPlatformPass
正式定义：
```matlab
aeroPlatformPass = ...
    results.targets.aeroLossPass && ...
    results.targets.frontShareMigrationPass;
```

说明：
- 本定义不把 clearance 逻辑并入
- 本定义也不直接等同于 `designPass`
- 这样才能用于 spring sweep 的双色/四色筛选

### scrapePassQuasiStatic
正式定义：
```matlab
scrapePassQuasiStatic = ...
    results.rules.staticGroundClearancePass && ...
    results.targets.dynamicClearancePass && ...
    ~results.flags.clearanceViolation;
```

### bump-adjusted clearance
对 `hDynamicAll` 的每个离地高点按前后位置做保守扣减：
- 前部点减 `reserveFront`
- 后部点减 `reserveRear`
- 中性点减 `max(reserveFront, reserveRear)`

新增输出：
- `results.clearance.hDynamicAllBumpAdjusted`
- `results.clearance.hDynamicMinBumpAdjusted`
- `results.clearance.hDynamicMinBumpAdjustedName`
- `results.clearance.dynamicClearanceBumpAdjustedPass`
- `results.clearance.dynamicClearanceBumpAdjustedMargin`

### scrapePassBumpAdjusted
正式定义：
```matlab
scrapePassBumpAdjusted = ...
    results.rules.staticGroundClearancePass && ...
    results.clearance.dynamicClearanceBumpAdjustedPass && ...
    ~results.flags.bumpAdjustedClearanceViolation;
```

说明：
- 静态赛规仍然只看 static clearance
- bump-adjusted pass 与 quasi-static pass 并存
- bump-adjusted 结果不会覆盖原始 dynamic clearance

### feasible 分层
继续保持：
- `converged`
- `rulePass`
- `designPass`
- `feasible`

## V1.0.4 新增 map 分类
### quasi-static 四色分类
`mapClassQuasiStatic`
- `0 = All Cases Fail`
- `1 = Only Aero Passes`
- `2 = Only Scrape Passes`
- `3 = Both Cases Pass`

### bump-adjusted 四色分类
`mapClassBumpAdjusted`
- `0 = All Cases Fail`
- `1 = Only Aero Passes`
- `2 = Only Scrape Passes`
- `3 = Both Cases Pass`

其中：
- aero 侧统一使用 `aeroPlatformPass`
- quasi-static 图的 scrape 侧使用 `scrapePassQuasiStatic`
- bump-adjusted 图的 scrape 侧使用 `scrapePassBumpAdjusted`

## spring sweep 工作流
### 新增函数
- `run_spring_sweep(baseCase, sweepDef, options)`
- `build_spring_sweep_cases(baseCase, sweepDef)`
- `plot_spring_sweep_map(sweepOut, mode, options)`
- `demo_spring_sweep_map()`

### spring sweep 的物理含义
- 扫参本质是：
  - 前轴左右同值地修改 `caseDef.sus.ks(1:2)`
  - 后轴左右同值地修改 `caseDef.sus.ks(3:4)`
- 求解器主链不变
- 不是新建独立的 heave spring 机构模型

### sweepOut 输出
至少包含：
- `frontSpringValues`
- `rearSpringValues`
- `resultGrid`
- `summaryTable`
- `classGridQuasiStatic`
- `colorGridQuasiStatic`
- `classGridBumpAdjusted`
- `colorGridBumpAdjusted`
- `metadata`

## 结果结构（核心）
- `results.state`
- `results.aero`
- `results.corners`
- `results.clearance`
- `results.rules`
- `results.targets`
- `results.flags`
- `results.metrics`
- `results.inputs / inputsRaw / inputsNominal`

V1.0.4 新增关键字段：
- `results.flags.aeroPlatformPass`
- `results.flags.scrapePassQuasiStatic`
- `results.flags.scrapePassBumpAdjusted`
- `results.flags.mapClassQuasiStatic`
- `results.flags.mapClassBumpAdjusted`
- `results.clearance.hDynamicAllBumpAdjusted`
- `results.clearance.hDynamicMinBumpAdjusted`
- `results.clearance.dynamicClearanceBumpAdjustedPass`
- `results.flags.bumpAdjustedClearanceViolation`
- `results.metrics.bumpReserveFront`
- `results.metrics.bumpReserveRear`

## run_batch summary 增强
`run_batch` summary 现在可直接筛选：
- `FrontSpring`
- `RearSpring`
- `hStaticMin`
- `hDynamicMin`
- `hDynamicMinBumpAdjusted`
- `staticGroundClearancePass`
- `dynamicClearancePass`
- `dynamicClearanceBumpAdjustedPass`
- `aeroLossPass`
- `frontShareMigrationPass`
- `aeroPlatformPass`
- `scrapePassQuasiStatic`
- `scrapePassBumpAdjusted`
- `mapClassQuasiStatic`
- `mapClassBumpAdjusted`
- `effectiveJounce`
- `effectiveDroop`
- `effectiveTotalTravel`
- `feasible`

## 标准 case 清洁原则
当前标准 case 至少包括：
- `build_case_2025_baseline`
- `build_case_2026_target`
- `demo_case_2026`

这些标准 case 的目标是：
- 当前活跃字段尽量显式给出
- 正常运行时不依赖 `validate_case_struct` 的 autofill warning 才成立
- 不再正式使用 `sus.kt`
- 不长期带着 shock/wheel consistency warning 运行

兼容机制仍然保留，但只服务于旧 case：
- autofill warning：暴露输入缺口与旧接口残留
- deprecated warning：暴露旧字段仍在被使用
- shock/wheel consistency warning：暴露机械约束矛盾

## 目录结构
- `main/`：主入口、批量入口、demo、spring sweep 工作流
- `config/`：默认参数与示例 case
- `core/`：validate / preprocess / solve / postprocess
- `aero/`：气动 map 与插值
- `utils/`：导出、sweep case 构建、map 分类工具
- `visualization/`：离地高图、姿态摘要图、spring sweep map
- `tests/`：回归与 V1.0.4 增量测试
- `docs/`：交接文档
- `data/`：示例数据

## 运行 Demo
```matlab
addpath(genpath('E:\JX Areo adaption\fs_platform_model'));

demo_case_2026;
demo_spring_sweep_map;
```

## 运行 Tests
```matlab
addpath(genpath('E:\JX Areo adaption\fs_platform_model'));

% 基础回归
test_zero_speed_zero_load;
test_static_symmetry;
test_roll_gradient_linear_case;
test_pitch_under_braking;

% V1.0.3 / V1.0.3a
test_delta_decomposition_consistency;
test_shock_stroke_from_susp_wheel;
test_rule_checks;
test_shock_wheel_consistency_warning;
test_tire_mode_off_fixed_range;
test_aero_map_flags;
test_static_dynamic_clearance_split;
test_static_clearance_rule_uses_static_values;
test_effective_travel_rule_check;
test_effective_jounce_rule_check;
test_range_results_inputs_consistency;
test_validation_warnings_emit;
test_run_batch_summary_fields_v103a;

% V1.0.4
test_aero_platform_pass_definition;
test_scrape_pass_quasi_static_definition;
test_bump_adjusted_clearance_split;
test_bump_adjusted_scrape_can_fail_when_quasi_static_pass;
test_spring_sweep_classification_codes;
test_run_batch_summary_fields_v104;
test_bump_adjust_input_expansion;
test_demo_spring_sweep_map_runs;
```

## Deprecated 字段策略
以下字段仍可读取，但只保留兼容，不再参与主求解：
- `sus.kt`
- `sus.kBump / bumpGap / kDroop / droopGap`
- `solver.useNonlinearCorner`
- `Fbump / Fdroop / bumpOn / droopOn`

当 `warnOnDeprecatedInput=true` 时，会通过真实 `warning(...)` 发射提示。
## V1.5 Update
本项目当前正式版本为 `V1.5`。
在保留 `V1.0 / V1.0.1 / V1.0.3a / V1.0.4` 工程骨架、`q = [z; theta; phi]` 主状态定义、以及 `run_case / run_batch` 主入口不变的前提下，当前版本新增了表格 / Excel 轮胎代理后评估层。

当前正式新增能力：
- `tire.forceModel.*`：轮胎横纵向表格代理接口
- `tireOp.*`：direct / proxy operating point 归一化输入层
- `results.tire.*`：`Fx / Fy / Mz / muX / muY / balance / utilization / peak margin`
- `results.corners.FzWheel`：轮胎代理层正式使用的角点法向载荷
- pure lateral / pure longitudinal / representative brake-in-turn / representative accel-out 评估能力

当前正式支持的数据源：
- `table_struct`
- `excel_file`

当前仅保留接口、首版未实现的数据源：
- `csv_longform`
- `tir_file`
- `function_handle`

当前边界：
- 轮胎层是平台主求解之后的后评估层，不回写主平衡方程
- 不是完整瞬态 bicycle / yaw 闭环求解器
- 不是完整 `.tir` / Magic Formula 平台
- 不是完整悬架外倾运动学求解器

当前应以本节和 `docs/FS_Platform_Model_Handover_V1.5_Tire_Proxy.md` 为准；下方 `V1.0.4` 内容保留为历史演化说明。

### V1.5 输入接口
- `caseDef.tire.mode / ktFront / ktRear / ktFrontRange / ktRearRange`
  - 继续只服务于垂向柔度与平台主求解
- `caseDef.tire.forceModel.enable`
- `caseDef.tire.forceModel.sourceType`
- `caseDef.tire.forceModel.mode`
- `caseDef.tire.forceModel.outOfRangePolicy`
- `caseDef.tire.forceModel.includeAligningMoment`
- `caseDef.tire.forceModel.combinedProxy.enable / type / exponent / useSeparateBrakeTraction`
- `caseDef.tireOp.mode = 'direct' | 'proxy'`
- `caseDef.tireOp.alpha / kappa / gamma / pressure`
- `caseDef.tireOp.alphaFront / alphaRear / kappaFront / kappaRear / gammaStatic / camberGainSusp / camberGainRoll / toeStatic`
- `caseDef.tireOp.scan.enable / field / values / unit / applyMode`

### 表格列名与 sheet 约定
- `FyTable`: `alpha, Fz, gamma, Fy`
- `MzTable`: `alpha, Fz, gamma, Mz`
- `FxTable`: `kappa, Fz, gamma, Fx`
- `Meta`: `tireName, source, pressure, alphaUnit, gammaUnit, kappaUnit, FzUnit, forceUnit, momentUnit, pressureUnit`
- 数组顺序固定为 `[FL FR RL RR]`
- 内部统一使用 SI

### combined proxy 说明
- 当没有 combined 表时，程序会基于 pure Fy/Fx 表和显式 `combinedProxy` 参数进行近似折减
- 当前近似本质是工程筛选层代理，不等价于完整 Magic Formula combined-slip

### V1.5 结果结构
- `results.tire.forceModel`
- `results.tire.inputs`
- `results.tire.forces`
- `results.tire.coeff`
- `results.tire.balance`
- `results.tire.validity`
- `results.tire.scan`
- `results.flags.tireForceModelEnabled / tireEvalFailed / tireOutOfRange / contactLostAny`

### V1.5 demo / tests
- `demo_tire_table_pure_lateral`
- `demo_tire_table_brake_in_turn`
- `plot_tire_table_scan`
- 轮胎代理层相关回归测试位于 `tests/test_tire_*.m`

### V1.5.0a Blocker Fix
`V1.5.0a` 本轮已完成一次阻塞级基础修复，重点不是新增 tire layer 功能，而是修复更前置的气动插值层 parser/debug 问题。

本轮修复结论：
- 修复 `aero/interp_aero_map.m` 的 parser/兼容性错误
- 将 `interp_aero_map.m` 收口为单主函数文件，移除尾部 local helper function
- 保留 4D aero map、clamp、nearest fallback、透明 flag 语义
- `demo_tire_table_pure_lateral` 与 `demo_tire_table_brake_in_turn`
  - 两者现已通过 aero map 原阻塞点并进入 tire layer

当前应结合以下文档理解本轮修复：
- `docs/FS_Platform_Model_Handover_V1.5_Tire_Proxy.md`
- `docs/FS_Platform_Model_Handover_V1.5_Implementation_Retrospective_2026-03-20.md`
- `docs/FS_Platform_Model_Handover_V1.5.0a_Aero_Parser_Debug_Fix_2026-03-21.md`
