# FS Platform Model 交接总览（V1.0 -> V1.0.1 -> V1.0.2 -> V1.0.3 -> V1.0.3a -> V1.0.4）

## 文档用途
本文件用于 `V1.0.4` 交接，作为后续继续维护 `fs_platform_model` 时的单一事实来源。
本次版本不是重建项目，也不是进入 `V1.5 / V2.0`，而是在 `V1.0.3a` 已收口的三自由度准静态平台模型基础上，补齐：
1. 前后弹簧二维 sweep 筛选图层
2. 基于准静态 dynamic clearance 的 bump-adjusted scrape robustness 图层

## 项目路径
- 项目根目录：`E:\JX Areo adaption\fs_platform_model`
- 交接文档目录：`E:\JX Areo adaption\fs_platform_model\docs`

## 版本连续性
1. `V1.0`
- 建立 `q = [z; theta; phi]` 的三自由度准静态平台模型
- 建立 heave / pitch / roll 与气动载荷耦合主链
- 提供 `run_case / run_batch / demo / tests / visualization` 工程框架

2. `V1.0.1`
- 停用 bump / droop 附加力，不再作为主求解器力项
- eye-to-eye 三长度成为正式输入
- wheel / shock 行程限制转为后处理约束

3. `V1.0.2`
- 保持主框架不变，进一步明确 `converged` 与 `feasible` 分层
- 气动插值开始输出 clamp / fallback 相关标志

4. `V1.0.3`
- 引入 `tire.mode = off / fixed / range`
- 重构 wheel / tire / shock 位移语义
- 正式引入 `rules / targets / feasible` 分层
- `run_batch` 可直接输出工程筛选 summary

5. `V1.0.3a`
- 正式拆分 `static clearance` 与 `dynamic clearance`
- `rules` 层只看静态离地高 + effective travel
- `targets` 层只看动态离地高
- 修正 `tire.mode='range'` 的 `results.inputs / inputsRaw / inputsNominal`
- `validation.warnings` 在 `warnOnDeprecatedInput=true` 时真实发射

6. `V1.0.4`（当前）
- 新增 spring sweep case 生成与 batch map 输出
- 新增 `aeroPlatformPass / scrapePassQuasiStatic / scrapePassBumpAdjusted`
- 新增 `bumpAdjust.reserveFront / reserveRear` 输入与 bump-adjusted clearance
- 新增 quasi-static 与 bump-adjusted 两套四分类 map

7. `V1.0.4` 进入 `V1.5` 前的接口清洁修订
- 标准 case 显式补齐当前活跃输入字段
- 标准轮胎输入正式迁移到 `tire.*`
- `sus.kt` 降级为纯 deprecated 兼容路径
- baseline / target / demo 正常运行时不再出现 autofill / `sus.kt` deprecated warning

## 主接口保持不变
以下接口未被破坏：
- `results = run_case(caseDef, options)`
- `batchOut = run_batch(caseArray, options)`
- `q = [z; theta; phi]`
- 既有 `results.state / aero / corners / clearance / rules / targets / flags / metrics`
- `tire.mode` 与 `range` 体系
- `static / dynamic clearance` 拆分
- `effective travel` 判据

## 标准 case 接口清洁结论
当前标准 case 至少包括：
- `build_case_2025_baseline`
- `build_case_2026_target`
- `demo_case_2026`

这些标准 case 的当前约定是：
1. 当前活跃字段应尽量显式给出，而不是依赖 autofill warning 才成立
2. 轮胎正式输入统一使用 `tire.mode / ktFront / ktRear / kt*Range`
3. `sus.kt` 只保留旧 case 兼容，不再出现在 baseline / target 正式输入中
4. shock/wheel consistency warning 机制仍保留，但标准 case 不应长期带着该 warning 运行

## 当前统一物理定义（V1.0.4）
### 状态与符号
- `z > 0`：车身下沉
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾

### 刚度链路
- `mr = spring / wheel`
- `kw = ks * mr^2`
- `keq` 由 `tire.mode` 决定：
  - `off`：`keq = kw`
  - `fixed / range`：`keq = kw * kt / (kw + kt)`

### 位移语义
- `deltaSuspWheel = Fmain ./ kw`
- `deltaTire = Fmain ./ kt`（off 模式为 0）
- `deltaGround = deltaSuspWheel + deltaTire`
- `shockStroke = mr .* deltaSuspWheel`

### effective travel
- `wheelJounceFromShock = shockCompAvail ./ mr`
- `wheelDroopFromShock  = shockReboundAvail ./ mr`
- `effectiveJounce = min(jounceMax, wheelJounceFromShock)`
- `effectiveDroop  = min(droopMax,  wheelDroopFromShock)`
- `effectiveTotalTravel = effectiveJounce + effectiveDroop`

## V1.0.4 新增输入：bumpAdjust
顶层新增：
```matlab
caseDef.bumpAdjust.enable
caseDef.bumpAdjust.reserveFront
caseDef.bumpAdjust.reserveRear
caseDef.bumpAdjust.notes
```

约定：
- 单位一律为 `m`
- 默认值为 `0`
- 可前后分开输入
- 若只给一侧，程序会自动扩展为前后同值
- 默认行为不影响 V1.0.3a 既有单点结果

## warning 机制的当前定位
以下 warning 机制仍然保留：
- autofill warning
- deprecated warning
- shock/wheel consistency warning

但它们当前的工程定位是：
- 服务于旧 case 兼容与输入歧义暴露
- 不是标准 case 的正常运行前提

因此：
- 标准 baseline / target / demo 应尽量在“开着 warning 机制”的情况下仍保持清洁运行

## pass / fail 定义（V1.0.4 新增重点）
### aeroPlatformPass
```matlab
aeroPlatformPass = ...
    results.targets.aeroLossPass && ...
    results.targets.frontShareMigrationPass;
```

说明：
- 这是 spring sweep map 的 aero 侧正式定义
- 不直接使用 `designPass`
- 不混入 clearance 逻辑

### scrapePassQuasiStatic
```matlab
scrapePassQuasiStatic = ...
    results.rules.staticGroundClearancePass && ...
    results.targets.dynamicClearancePass && ...
    ~results.flags.clearanceViolation;
```

说明：
- static 赛规仍然只看静态离地高
- dynamic clearance 仍使用原始准静态 dynamic clearance

### bump-adjusted clearance
对 `hDynamicAll` 的各 clearance 点做保守扣减：
- 前部点减 `reserveFront`
- 后部点减 `reserveRear`
- 中性点减 `max(reserveFront, reserveRear)`

新增输出：
- `results.clearance.hDynamicAllBumpAdjusted`
- `results.clearance.hDynamicMinBumpAdjusted`
- `results.clearance.hDynamicMinBumpAdjustedName`
- `results.clearance.dynamicClearanceBumpAdjustedPass`
- `results.clearance.dynamicClearanceBumpAdjustedMargin`
- `results.flags.bumpAdjustedClearanceViolation`

### scrapePassBumpAdjusted
```matlab
scrapePassBumpAdjusted = ...
    results.rules.staticGroundClearancePass && ...
    results.clearance.dynamicClearanceBumpAdjustedPass && ...
    ~results.flags.bumpAdjustedClearanceViolation;
```

说明：
- 该判据比 quasi-static scrape 更保守
- 不覆盖原始 `hDynamicMin`
- 目的是做 robustness screening，不是冒充完整瞬态结果

## 四色分类 map 定义
### class code
- `0 = All Cases Fail`
- `1 = Only Aero Passes`
- `2 = Only Scrape Passes`
- `3 = Both Cases Pass`

### quasi-static 图
- aero 侧：`aeroPlatformPass`
- scrape 侧：`scrapePassQuasiStatic`
- 输出：`mapClassQuasiStatic / mapClassQuasiStaticLabel / mapClassQuasiStaticColor`

### bump-adjusted 图
- aero 侧：`aeroPlatformPass`
- scrape 侧：`scrapePassBumpAdjusted`
- 输出：`mapClassBumpAdjusted / mapClassBumpAdjustedLabel / mapClassBumpAdjustedColor`

## spring sweep 工作流
### 新增文件
- `main/run_spring_sweep.m`
- `main/demo_spring_sweep_map.m`
- `visualization/plot_spring_sweep_map.m`
- `utils/build_spring_sweep_cases.m`
- `utils/classify_spring_sweep_map.m`

### 扫参方式
- 前轴左右同值修改 `sus.ks(1:2)`
- 后轴左右同值修改 `sus.ks(3:4)`
- 内部计算始终保持 SI（`N/m`）
- 图上可切换显示 `N/m` 或 `lbf/in`

### sweepOut 结构
至少包含：
- `frontSpringValues`
- `rearSpringValues`
- `resultGrid`
- `summaryTable`
- `classGridQuasiStatic / colorGridQuasiStatic`
- `classGridBumpAdjusted / colorGridBumpAdjusted`
- `metadata`

## run_batch summary（V1.0.4 重点字段）
新增或保证保留：
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

## V1.0.4 与 V1.0.3a 的差异总结
1. `V1.0.3a` 侧重单点结果语义和 rule/target 分层
2. `V1.0.4` 在不改 solver 主链的前提下，增加：
- sweep 筛选图层
- quasi-static 与 bump-adjusted 两套 scrape pass
- aero/scrape 分离的四色分类
- bump-adjusted clearance 鲁棒性输出

3. `V1.0.4` 没有做的事情：
- 没有把 bump 写回主平衡方程
- 没有新增状态自由度
- 没有进入 V1.5 的 grip / balance proxy
- 没有进入 V2.0 的 transient bicycle

## 新增测试（V1.0.4）
已新增：
1. `test_aero_platform_pass_definition`
2. `test_scrape_pass_quasi_static_definition`
3. `test_bump_adjusted_clearance_split`
4. `test_bump_adjusted_scrape_can_fail_when_quasi_static_pass`
5. `test_spring_sweep_classification_codes`
6. `test_run_batch_summary_fields_v104`
7. `test_demo_spring_sweep_map_runs`
8. `test_bump_adjust_input_expansion`

## 物理边界说明（必须保留）
`V1.0.4` bump-adjusted 功能的工程定位是：
- 对准静态 dynamic clearance 的保守修正
- 用于 spring sweep 方案筛选时的 scrape robustness screening

它不是：
- 真实路谱激励下的瞬态 ride 仿真
- 带阻尼速度项的时域模型
- 带轮胎载荷敏感度与抓地代理的 V1.5
- 带 bicycle transient 的 V2.0

## 建议后续方向
1. 若继续做 `V1.5`，可在保持本主链不变的前提下加入 tire load sensitivity / grip proxy
2. 若继续做 `V2.0`，再引入 transient bicycle 与工况分段分析
3. 当前 `V1.0.4` 已足够用于前后弹簧组合筛选与保守 scrape robustness 对比
