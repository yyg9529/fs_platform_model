# FS Platform Model 交接复盘文档（V1.5｜Implementation Retrospective）

## 文档用途
本文件用于复盘本次 `V1.5` 落地修改，并给下一线程提供一份更偏“工程实现视角”的交接说明。

它与 `docs/FS_Platform_Model_Handover_V1.5_Tire_Proxy.md` 的区别是：
- `V1.5_Tire_Proxy` 更偏版本说明与接口结论
- 本文更偏本次具体做了什么、为什么这样做、验证到了什么程度、后续该怎么接

当前时间基准：
- 形成日期：`2026-03-20`
- 当前工程基线：`V1.5`

## 本次任务的最终结论
本次修改已经把当前 `fs_platform_model` 从“接口清洁后的 `V1.0.4` 稳定版”升级为可实际使用的 `V1.5` 首版。

本次升级严格保持了以下主线不变：
- 主目录结构未重建
- `run_case / run_batch` 主入口未改名
- 主流程仍是 `validate -> preprocess -> solve -> postprocess`
- 三自由度准静态平台主求解链未被轮胎层侵入
- `tire.mode = off / fixed / range` 的垂向柔度语义未被破坏
- `static / dynamic clearance`、`rules / targets / feasible`、`spring sweep`、`bump-adjusted scrape map` 继续成立

在这个前提下，本次已经新增：
1. 表格 / Excel 轮胎代理后评估层
2. `direct / proxy` operating point 归一化输入层
3. 四角点 `Fx / Fy / Mz / muX / muY`
4. 前后轴 `balance / utilization / peak margin`
5. 代表性纯工况与联合工况 scan
6. 面向未来 `.tir / Magic Formula` 的 `sourceType` 预留接口

## 本次实现的核心设计决策
### 1. 严格分离“垂向柔度”与“轮胎力代理”
保留：
- `caseDef.tire.mode`
- `caseDef.tire.ktFront`
- `caseDef.tire.ktRear`
- `caseDef.tire.ktFrontRange`
- `caseDef.tire.ktRearRange`

新增：
- `caseDef.tire.forceModel.*`

结论：
- `tire.mode` 继续只服务于平台主求解中的垂向柔度
- `tire.forceModel` 只服务于平台收敛后的轮胎横纵向后评估
- 两者没有被混写成一套模糊接口

### 2. 轮胎层严格挂在平台主求解之后
本次没有把轮胎代理层偷偷混进 `K*q=Qext` 主平衡。

当前真实流程是：

```matlab
run_case
-> validate_case_struct
-> preprocess_case
-> solve_equilibrium
-> postprocess_results
-> apply_tire_force_layer
```

这意味着：
- 平台主求解仍由 `man.V / man.ax / man.ay / man.beta` 驱动
- 轮胎层只是读平台结果，不反向改平台姿态
- `V1.0.4` 旧行为可以在 `tire.forceModel.enable=false` 时完整保持

### 3. 轮胎层所用 `Fz` 明确来自平台结果
本次正式新增：
- `results.corners.FzWheel`

用途：
- 轮胎代理层统一从这里读取四角点法向载荷
- 不允许用户再另外手填一套与平台脱节的 `Fz`

### 4. 首版 combined 工况采用显式 proxy，而不是伪装成完整 MF
当前首版的联合工况策略是：
- 若未来有 `CombinedTable`，优先走 combined 表
- 当前默认只有 pure Fy/Fx/Mz 表时，使用 `combinedProxy`
- `combinedProxy` 的指数、类型、是否区分 brake/traction capacity 都做成了显式字段

这条设计很重要，因为它把“当前可落地版本”和“未来完整模型”边界划清了。

### 5. 轮胎层失败不拖垮平台结果
本次在 `run_case` 中单独包了一层轮胎后处理 `try/catch`。

当前行为：
- 平台主求解成功后，即使轮胎层失败，也保留平台结果
- 同时置位：
  - `results.flags.tireForceModelEnabled`
  - `results.flags.tireEvalFailed`
- 并保留错误信息到 `results.debug.tireForceModelError`

这满足了“不要因为轮胎代理层评估失败就把平台主结果一起清空”的要求。

## 本次新增的正式实现模块
### `config/`
- `build_demo_tire_force_tables.m`

作用：
- 生成一套可直接用于 `table_struct` 的示例轮胎长表数据
- 被 demo 和测试复用

### `core/`
- `load_tire_table_data.m`
- `normalize_tire_operating_points.m`
- `evaluate_tire_table_model.m`
- `evaluate_tire_combined_proxy.m`
- `postprocess_tire_results.m`

作用：
- 统一读取并归一化轮胎表格 / Excel 数据
- 统一 `direct / proxy` operating point
- 评估 pure Fy / pure Fx / pure Mz
- 在仅有 pure 表时生成 combined proxy 结果
- 将结果组织进正式 `results.tire` 结构

### `main/`
- `demo_tire_table_pure_lateral.m`
- `demo_tire_table_brake_in_turn.m`

作用：
- 演示纯侧偏与代表性 brake-in-turn 两类 `V1.5` 使用方式

### `visualization/`
- `plot_tire_table_scan.m`

作用：
- 对 `results.tire.scan` 做统一可视化

### 修改的既有主文件
- `main/run_case.m`
- `main/run_batch.m`
- `core/postprocess_results.m`
- `core/validate_case_struct.m`
- `config/build_case_2025_baseline.m`
- `config/build_case_2026_target.m`
- `README.md`

## 本次对输入接口的具体收口
### 标准 case
标准 case 已经显式补齐：
- `tire.forceModel.*`
- `tireOp.*`

处理原则：
- 标准 case 不依赖 autofill warning 才成立
- 但对“不激活时允许为空”的字段，例如：
  - `tire.forceModel.file`
  - `tireOp.scan.field / values / unit`
  做了 reportable autofill 过滤

这样既保留了兼容机制，又保证标准 case warning-clean。

### loader 当前正式支持
当前 loader 已正式落地：
- `sourceType='table_struct'`
- `sourceType='excel_file'`

当前只做接口保留、首版未实现：
- `csv_longform`
- `tir_file`
- `function_handle`

说明：
- 这不是遗漏，而是当前版本的有意边界
- 目的是优先让 `V1.5` 首版真实可用，而不是为了未来 `.tir` 把首版拖成半成品

## 本次对结果结构的具体收口
### 保留的旧字段
本次没有删除或重命名旧的关键主层级：
- `results.state`
- `results.aero`
- `results.corners`
- `results.clearance`
- `results.rules`
- `results.targets`
- `results.flags`
- `results.metrics`

### 本次正式新增
#### `results.corners`
- `FzWheel`

#### `results.tire`
- `forceModel`
- `inputs`
- `forces`
- `coeff`
- `balance`
- `validity`
- `scan`

#### `results.flags`
- `tireForceModelEnabled`
- `tireEvalFailed`
- `tireOutOfRange`
- `contactLostAny`

#### `results.metrics`
- `balanceIndex`
- `peakMarginFront`
- `peakMarginRear`
- `maxAbsMuX`
- `maxAbsMuY`

#### `run_batch summary`
新增：
- `tireEvalFailed`
- `tireOutOfRange`
- `contactLostAny`
- `FyFrontTotal`
- `FyRearTotal`
- `FxFrontTotal`
- `FxRearTotal`
- `frontFyShare`
- `rearFyShare`
- `balanceIndex`
- `peakMarginFront`
- `peakMarginRear`
- `maxAbsMuY`
- `maxAbsMuX`

## 本次验证与自测结果
### 静态检查
已对本轮新增 / 关键修改文件执行 `checkcode`。

最终结果：
- `TOTAL_CHECKCODE_MESSAGES=0`

### 回归测试
已执行完整测试集，包括旧版与新增测试。

最终结果：
- `TOTAL_TESTS=52`
- `TOTAL_FAILURES=0`

### 本次新增并通过的 `V1.5` 相关测试
- `test_tire_table_disabled_keeps_v104_behavior`
- `test_tire_table_struct_load`
- `test_tire_excel_load`
- `test_tire_op_direct_scalar_expand`
- `test_tire_op_proxy_generation`
- `test_fy_alpha_interpolation`
- `test_fx_kappa_interpolation`
- `test_mz_alpha_interpolation`
- `test_out_of_range_policy_warn_clamp`
- `test_contact_loss_flag`
- `test_combined_proxy_brake_in_turn`
- `test_tire_results_fields_exist`
- `test_run_batch_summary_with_tire`
- `test_demo_tire_table_pure_lateral_runs`
- `test_demo_tire_table_brake_in_turn_runs`

### 测试中出现的 warning 说明
以下 warning 在测试中出现是预期行为，不代表工程失败：
- out-of-range clamp warning
  - 用于验证 `warn_clamp` 策略
- shock/wheel consistency warning
  - 用于验证机械一致性 warning 仍然有效
- deprecated warning
  - 用于验证兼容层 warning 仍然可发射

## 本次实现后，当前模型已经能做什么
1. 先用平台主求解器求出姿态、载荷、clearance、travel。
2. 再用平台结果中的四角点 `Fz` 驱动轮胎代理层。
3. 给出四角点 `Fx / Fy / Mz` 与 `muX / muY`。
4. 给出前后轴 `balanceIndex / frontFyShare / peakMarginFront / peakMarginRear`。
5. 对 pure lateral / pure longitudinal / representative brake-in-turn 做 scan。
6. 在 `run_batch` summary 里直接筛选轮胎 balance / utilization 结果。

## 当前仍未进入的内容
本次没有进入，也不应在下一线程里误写成“已经支持”的内容：
- 完整瞬态 bicycle / yaw 闭环
- 完整轮速动力学
- 完整制动液压闭环
- 完整驱动系统闭环
- 完整悬架外倾运动学
- 通用 `.tir` parser
- 完整 Magic Formula 参数层

## 下一线程最建议优先做的方向
如果继续做 `V1.5+`，建议优先顺序如下：

1. 完成 `csv_longform` 适配器
- 这与当前 table/excel 路线最接近
- 改动集中在 loader 层，不需要重写上层接口

2. 增加可选 `CombinedTable`
- 让已有 `combinedProxy` 路径与真实 combined 表并存
- 当前 `results.tire` 结构已经预留好了

3. 提升 balance 指标体系
- 当前 `balanceIndex = front peak utilization - rear peak utilization`
- 后续可以在不改主接口的前提下增加更多 proxy

4. 再考虑 `.tir` 适配层
- 建议尽量只替换 evaluator / adapter 层
- 不要重写 `tire.forceModel / tireOp / results.tire`

## 给下一线程的直接结论
下一线程如果时间有限，建议先读：
1. `README.md`
2. `docs/FS_Platform_Model_Handover_V1.5_Tire_Proxy.md`
3. 本文
4. `main/run_case.m`
5. `core/load_tire_table_data.m`
6. `core/normalize_tire_operating_points.m`
7. `core/evaluate_tire_table_model.m`
8. `core/postprocess_tire_results.m`

一句话总结本次收口结果：

**当前工程已经具备“平台主求解保持不动、轮胎代理层后挂、四角点力与前后轴 balance 可直接输出”的 `V1.5` 首版能力，并且全量回归已通过。**
