# FS Platform Model 跨线程总交接文档（截至 V1.0.4）

## 文档用途
本文件不是替代各版本交接文档，而是在以下文档基础上做一次跨线程总收口：
- `FS_Platform_Model_Handover_V1.0_to_V1.0.2.md`
- `FS_Platform_Model_Handover_V1.0_to_V1.0.3.md`
- `FS_Platform_Model_Handover_V1.0_to_V1.0.3a.md`
- `FS_Platform_Model_Handover_V1.0_to_V1.0.4.md`
- `README.md`

本文件的目标是给后续线程一个更稳定的单一事实来源，避免每次都要在多份版本文档之间来回比对。
当前基线版本为 `V1.0.4`。

## 一句话定义
`fs_platform_model` 当前可以定义为：

**一个保持 `q = [z; theta; phi]` 三自由度准静态平台模型定位不变、支持 `tire.mode`、支持 static/dynamic clearance 分离、支持 effective travel 判据、支持前后弹簧二维 sweep 筛选图与 bump-adjusted scrape robustness 图的悬架-气动参数化工程模型。**

## 版本继承关系
### 1. V1.0
- 建立三自由度准静态平台模型：`q = [z; theta; phi]`
- 建立 heave / pitch / roll 与气动载荷耦合主链
- 形成完整工程结构：`main/config/core/aero/utils/visualization/tests/docs/data`
- 建立 `run_case / run_batch / demo / tests / visualization` 主框架

### 2. V1.0.1
- 停用 bump / droop 附加力，不再作为主平衡方程力项
- 引入 eye-to-eye shock 输入：
  - `shockLenExtended`
  - `shockLenCompressed`
  - `shockLenStatic`
- 将 wheel / shock 行程限制转为后处理约束与 violation flag

### 3. V1.0.2
- 进一步明确 `converged` 与 `feasible` 分层
- 强化气动插值的可追踪性：`mapClamped`、`interpFallbackUsed`
- 这一版文档中曾将主平衡统一表述为 `keq = kw`

### 4. V1.0.3
- 正式引入 `tire.mode = off / fixed / range`
- 重新建立当前仍在使用的刚度链：
  - `off`: `keq = kw`
  - `fixed / range`: `keq = kw * kt / (kw + kt)`
- 重构位移语义：
  - `deltaSuspWheel`
  - `deltaTire`
  - `deltaGround`
  - `shockStroke`
- 新增 `rules / targets / feasible` 分层判据
- `run_batch` 升级为可直接筛方案的 summary

### 5. V1.0.3a
- 正式拆分 `static clearance` 与 `dynamic clearance`
- `rules` 层只看静态离地高与 effective travel
- `targets` 层只看动态离地高与姿态/气动窗口
- 修正 `tire.mode='range'` 下的 `results.inputs / inputsRaw / inputsNominal`
- `validation.warnings` 可真实通过 `warning(...)` 发射

### 6. V1.0.4（当前）
- 新增前后弹簧二维 sweep 工作流
- 新增 `aeroPlatformPass`
- 新增 `scrapePassQuasiStatic`
- 新增 `scrapePassBumpAdjusted`
- 新增 `bumpAdjust.reserveFront / reserveRear`
- 新增 quasi-static 与 bump-adjusted 两套四色分类 map
- 明确本版本是“筛选层增强 + 鲁棒性层增强”，不是完整瞬态模型
- 在进入 `V1.5` 前完成一次接口清洁修订：
  - 标准 case 显式补齐活跃字段
  - 标准轮胎输入正式迁移到 `tire.*`
  - `sus.kt` 仅保留 deprecated 兼容
  - baseline / target / demo 正常运行时不再出现 autofill / `sus.kt` deprecated warning

## 需要特别澄清的历史差异
### 1. 关于 `keq`
这是跨线程最容易混淆的点。
- `V1.0.2` 文档中的 `keq = kw` 是当时阶段性收口定义
- 从 `V1.0.3` 起，当前代码基线已经改为 `tire.mode` 驱动的模式化处理：
  - `off`：`keq = kw`
  - `fixed/range`：`keq = kw * kt / (kw + kt)`

因此：
- 如果讨论“当前版本代码逻辑”，以 `V1.0.4` 的 `tire.mode` 语义为准
- 如果讨论“版本演化历史”，则 `V1.0.2` 的 `keq=kw` 结论只作为历史阶段说明，不应再当成当前代码事实

### 2. 关于 bump
- `V1.0.1` 已经明确：bump / droop 不回到主平衡方程
- `V1.0.4` 新增的 `bumpAdjust` 只是对准静态 dynamic clearance 的保守修正
- `bumpAdjust` 不是回退到早期 bump 附加力模型，更不是瞬态 ride 求解器

## 当前不得破坏的主结构
### 1. 接口
- 单工况入口：`results = run_case(caseDef, options)`
- 批量入口：`batchOut = run_batch(caseArray, options)`

### 2. 目录结构
- `main/`
- `config/`
- `core/`
- `aero/`
- `utils/`
- `visualization/`
- `tests/`
- `docs/`
- `data/`

### 3. 状态定义与符号
- `q = [z; theta; phi]`
- `z > 0`：车身下沉
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾

### 4. 顶层结构
- `caseDef` 顶层结构仍保持统一
- `results` 顶层结构仍保持统一
- eye-to-eye 输入体系仍保留

## 当前标准 case 接口结论
当前标准 case 至少包括：
- `build_case_2025_baseline`
- `build_case_2026_target`
- `demo_case_2026`

当前结论：
1. 标准 case 应显式给出当前活跃字段，不应依赖 autofill warning 才成立
2. 标准轮胎输入已正式统一到 `tire.mode / ktFront / ktRear / ktFrontRange / ktRearRange`
3. `sus.kt` 只保留给旧 case 兼容，不再属于正式标准 case 输入
4. autofill / deprecated / consistency warning 机制仍保留，但主要用于旧 case 与异常输入暴露

## 当前统一物理语义（以 V1.0.4 为准）
### 1. 刚度链
- `mr = spring / wheel`
- `kw = ks * mr^2`
- `keq` 由 `tire.mode` 决定：
  - `off`：`keq = kw`
  - `fixed / range`：`keq = kw * kt / (kw + kt)`

### 2. 位移语义
- `deltaSuspWheel = Fmain ./ kw`
- `deltaTire = Fmain ./ kt`（`tire.mode='off'` 时置 0）
- `deltaGround = deltaSuspWheel + deltaTire`
- `shockStroke = mr .* deltaSuspWheel`

### 3. clearance 语义
- `hStaticAll / hStaticMin / hStaticMinName`：静态离地高
- `hDynamicAll / hDynamicMin / hDynamicMinName`：准静态动态离地高
- 兼容字段 `hAll / hMin / hMinName` 继续映射到 dynamic clearance

### 4. effective travel 语义
- `wheelJounceFromShock = shockCompAvail ./ mr`
- `wheelDroopFromShock  = shockReboundAvail ./ mr`
- `effectiveJounce = min(jounceMax, wheelJounceFromShock)`
- `effectiveDroop  = min(droopMax, wheelDroopFromShock)`
- `effectiveTotalTravel = effectiveJounce + effectiveDroop`

## 当前输入结构重点
### caseDef 顶层重点字段
- `meta`
- `veh`
- `sus`
- `tire`
- `rules`
- `targets`
- `longi`
- `aero`
- `ref`
- `man`
- `solver`
- `bumpAdjust`

### tire
- `mode`
- `ktFront`, `ktRear`
- `ktFrontRange`, `ktRearRange`
- `notes`

### rules
- `ruleSet`
- `minStaticGroundClearance`
- `minUsableWheelTravelTotal`
- `minJounce`
- `enforceRules`

### targets
- `minDynamicClearance`
- `maxPitchDeg`
- `maxRollDeg`
- `maxAeroLossPct`
- `maxFrontShareMigrationPct`
- `enforceTargets`

### bumpAdjust
- `enable`
- `reserveFront`
- `reserveRear`
- `notes`

约定：
- 单位一律为 `m`
- 若只给一侧 reserve，当前实现会自动扩展为前后同值
- 默认值为 0，默认不影响既有单点结果

## 当前输出结构重点
### results 主层级
- `results.state`
- `results.aero`
- `results.tire`
- `results.corners`
- `results.clearance`
- `results.rules`
- `results.targets`
- `results.flags`
- `results.metrics`
- `results.inputs / inputsRaw / inputsNominal`

### V1.0.4 重点新增字段
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

## 当前正式判据层
### 1. rules 层
当前只看：
- `staticGroundClearancePass`
- `usableWheelTravelPass`
- `minJouncePass`

### 2. targets 层
当前只看：
- `dynamicClearancePass`
- `pitchPass`
- `rollPass`
- `aeroLossPass`
- `frontShareMigrationPass`

### 3. flags 分层
当前仍保持：
- `converged`
- `rulePass`
- `designPass`
- `feasible`

## V1.0.4 新增的正式 pass 定义
### 1. aeroPlatformPass
```matlab
aeroPlatformPass = ...
    results.targets.aeroLossPass && ...
    results.targets.frontShareMigrationPass;
```

关键点：
- 不混入 clearance 逻辑
- 不直接等同于 `designPass`
- 这是 spring sweep map 中 aero 侧的正式定义

### 2. scrapePassQuasiStatic
```matlab
scrapePassQuasiStatic = ...
    results.rules.staticGroundClearancePass && ...
    results.targets.dynamicClearancePass && ...
    ~results.flags.clearanceViolation;
```

关键点：
- static rule 仍然只看静态离地高
- dynamic clearance 使用原始准静态 `hDynamic*`

### 3. bump-adjusted clearance
对 `hDynamicAll` 的各 clearance 点做保守扣减：
- 前部点减 `reserveFront`
- 后部点减 `reserveRear`
- 中性点减 `max(reserveFront, reserveRear)`

新增结果：
- `hDynamicAllBumpAdjusted`
- `hDynamicMinBumpAdjusted`
- `hDynamicMinBumpAdjustedName`
- `dynamicClearanceBumpAdjustedPass`
- `dynamicClearanceBumpAdjustedMargin`
- `bumpAdjustedClearanceViolation`

### 4. scrapePassBumpAdjusted
```matlab
scrapePassBumpAdjusted = ...
    results.rules.staticGroundClearancePass && ...
    results.clearance.dynamicClearanceBumpAdjustedPass && ...
    ~results.flags.bumpAdjustedClearanceViolation;
```

关键点：
- 比 quasi-static scrape 更保守
- 不覆盖原始 dynamic clearance
- 只用于 robustness screening

## V1.0.4 四色分类逻辑
### class code
- `0 = All Cases Fail`
- `1 = Only Aero Passes`
- `2 = Only Scrape Passes`
- `3 = Both Cases Pass`

### quasi-static 图
- aero 侧：`aeroPlatformPass`
- scrape 侧：`scrapePassQuasiStatic`
- 结果字段：`mapClassQuasiStatic`

### bump-adjusted 图
- aero 侧：`aeroPlatformPass`
- scrape 侧：`scrapePassBumpAdjusted`
- 结果字段：`mapClassBumpAdjusted`

## 当前 batch 与 sweep 能力
### run_batch summary 已可直接筛选
重点字段包括：
- `FrontSpring`
- `RearSpring`
- `hStaticMin`
- `hDynamicMin`
- `hDynamicMinBumpAdjusted`
- `staticGroundClearancePass`
- `dynamicClearancePass`
- `dynamicClearanceBumpAdjustedPass`
- `aeroPlatformPass`
- `scrapePassQuasiStatic`
- `scrapePassBumpAdjusted`
- `mapClassQuasiStatic`
- `mapClassBumpAdjusted`
- `effectiveJounce`
- `effectiveDroop`
- `effectiveTotalTravel`
- `feasible`

### V1.0.4 新增工作流
- `run_spring_sweep(baseCase, sweepDef, options)`
- `build_spring_sweep_cases(baseCase, sweepDef)`
- `plot_spring_sweep_map(sweepOut, mode, options)`
- `demo_spring_sweep_map()`

### spring sweep 的物理含义
- 前轴左右同值修改 `sus.ks(1:2)`
- 后轴左右同值修改 `sus.ks(3:4)`
- 求解器主链不变
- 这是方案筛选层增强，不是新求解器

## 当前 deprecated / 兼容策略
以下字段仍可读取，但不再参与当前主求解：
- `sus.kt`（建议迁移到 `tire.*`）
- `sus.kBump / bumpGap / kDroop / droopGap`
- `solver.useNonlinearCorner`
- `Fbump / Fdroop / bumpOn / droopOn`

策略：
- 继续兼容读取
- 发出 warning
- 不 silently 参与主求解

## 当前物理边界
### 当前模型是
- 三自由度准静态平台模型
- 单点工况分析工具
- 工程规则判据工具
- 前后弹簧组合筛选工具
- 准静态结果上的保守 scrape robustness 工具

### 当前模型不是
- 完整瞬态 ride / bump 动力学模型
- 带 damper velocity 的时域模型
- 带 tire load sensitivity / grip proxy 的 V1.5
- 带 bicycle transient / turn-in / exit balance 的 V2.0

## 当前测试状态总结
### 历史保留基础测试
- `test_zero_speed_zero_load`
- `test_static_symmetry`
- `test_roll_gradient_linear_case`
- `test_pitch_under_braking`

### V1.0.3 / V1.0.3a 关键测试
- `test_delta_decomposition_consistency`
- `test_shock_stroke_from_susp_wheel`
- `test_rule_checks`
- `test_shock_wheel_consistency_warning`
- `test_tire_mode_off_fixed_range`
- `test_aero_map_flags`
- `test_static_dynamic_clearance_split`
- `test_static_clearance_rule_uses_static_values`
- `test_effective_travel_rule_check`
- `test_effective_jounce_rule_check`
- `test_range_results_inputs_consistency`
- `test_validation_warnings_emit`
- `test_run_batch_summary_fields_v103a`

### V1.0.4 新增测试
- `test_aero_platform_pass_definition`
- `test_scrape_pass_quasi_static_definition`
- `test_bump_adjusted_clearance_split`
- `test_bump_adjusted_scrape_can_fail_when_quasi_static_pass`
- `test_spring_sweep_classification_codes`
- `test_run_batch_summary_fields_v104`
- `test_demo_spring_sweep_map_runs`
- `test_bump_adjust_input_expansion`

### 最近状态
- 旧测试与 V1.0.4 新测试已全部通过
- `checkcode` 已清零：`TOTAL_CHECKCODE_MESSAGES=0`
- MATLAB 终端 warning 文本可能存在编码乱码，但不影响逻辑与测试结论

## 后续线程最值得先读的内容
如果下一个线程时间有限，建议优先阅读顺序：
1. `README.md`
2. 本文档
3. `FS_Platform_Model_Handover_V1.0_to_V1.0.4.md`
4. `main/run_case.m`
5. `core/postprocess_results.m`
6. `main/run_spring_sweep.m`
7. `visualization/plot_spring_sweep_map.m`

## 建议的下一阶段方向
### 如果继续做 V1.5
建议新增：
- tire load sensitivity
- grip / balance proxy
- 更强的气动窗口与轴载迁移联动分析

前提：
- 不破坏当前 `run_case / run_batch` 主接口
- 不回退当前 `static / dynamic clearance` 语义
- 不回退当前 `rules / targets / feasible` 分层

### 如果继续做 V2.0
那时再考虑：
- transient bicycle
- turn-in / mid-corner / exit 分段工况
- 更完整的时域 ride / event 模型

## 本文档校验记录
本文件形成前已对以下内容逐项回查：
1. `V1.0 -> V1.0.1 -> V1.0.2 -> V1.0.3 -> V1.0.3a -> V1.0.4` 版本链是否连续
2. `run_case / run_batch` 主接口是否保持不变
3. `q = [z; theta; phi]` 的物理定义是否保持不变
4. `tire.mode`、`static/dynamic clearance`、`effective travel` 是否仍为当前代码基线
5. `aeroPlatformPass / scrapePassQuasiStatic / scrapePassBumpAdjusted` 是否与 V1.0.4 文档一致
6. `bumpAdjust` 是否被明确限定为保守修正层而非瞬态求解器
7. `run_batch` 与 `spring sweep` 的筛选层语义是否明确
8. deprecated 字段是否仍保持“兼容读取但不参与主求解”的策略
9. 测试状态与 `checkcode` 结论是否与当前工程状态一致
