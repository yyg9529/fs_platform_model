# FS Platform Model 交接文档（V1.5｜Tire Proxy Layer）

## 文档用途
本文件用于记录 `V1.5` 的正式新增内容。
本轮不是重建工程，也不是进入完整瞬态操稳求解；它是在 `V1.0.4 + Pre-V1.5 Interface Cleanup` 基线上，新增表格 / Excel 轮胎代理后评估层、operating point 归一化层、前后轴 balance/utilization 结果层，以及代表性轮胎工况 scan 能力。

## 本次修订的核心定位
`V1.5` 继续保持：
- 三自由度准静态平台模型
- `q = [z; theta; phi]`
- `run_case / run_batch` 主入口
- `static / dynamic clearance` 分层
- `rules / targets / feasible` 分层
- `spring sweep / bump-adjusted scrape map` 框架

`V1.5` 新增：
1. `tire.forceModel.*` 轮胎横纵向代理层
2. `tireOp.*` operating point 输入层
3. `results.tire.*` 正式结果层
4. 代表性 pure / combined 工况 scan
5. `sourceType='tir_file'` 的未来接口预留

## 当前主流程
当前主流程仍是：

```matlab
run_case
-> default_solver_options
-> validate_case_struct
-> preprocess_case
-> solve_equilibrium
-> postprocess_results
-> if tire.forceModel.enable
      load_tire_table_data
      normalize_tire_operating_points
      evaluate_tire_table_model
      postprocess_tire_results
   end
```

关键结论：
- 轮胎代理层严格位于平台主求解之后
- `Fz` 必须来自平台收敛后的 `results.corners.FzWheel`
- 轮胎层失败只置位 `results.flags.tireEvalFailed`，不清空平台主结果

## V1.5 输入接口
### 垂向柔度
继续保留：
- `caseDef.tire.mode`
- `caseDef.tire.ktFront`
- `caseDef.tire.ktRear`
- `caseDef.tire.ktFrontRange`
- `caseDef.tire.ktRearRange`

说明：
- 这些字段只服务于垂向柔度与平台主求解
- 不允许与 `tire.forceModel` 混淆

### 轮胎代理层
当前正式支持：
- `caseDef.tire.forceModel.enable`
- `caseDef.tire.forceModel.sourceType='table_struct'|'excel_file'`
- `caseDef.tire.forceModel.mode='pure_tables'|'pure_plus_combined_proxy'`
- `caseDef.tire.forceModel.outOfRangePolicy='warn_clamp'|'error'|'nan'`
- `caseDef.tire.forceModel.includeAligningMoment`
- `caseDef.tire.forceModel.alphaUnit / gammaUnit / kappaUnit / FzUnit / forceUnit / momentUnit / pressureUnit`
- `caseDef.tire.forceModel.combinedProxy.enable / type / exponent / useSeparateBrakeTraction`

当前保留接口但首版未实现：
- `sourceType='csv_longform'`
- `sourceType='tir_file'`
- `sourceType='function_handle'`

### operating point
`caseDef.tireOp.mode='direct'` 时：
- `alpha`
- `kappa`
- `gamma`
- `pressure`

`caseDef.tireOp.mode='proxy'` 时：
- `alphaFront / alphaRear`
- `kappaFront / kappaRear`
- `gammaStatic`
- `camberGainSusp`
- `camberGainRoll`
- `toeStatic`
- `pressure`

当前 proxy 外倾公式：

```matlab
gamma = gammaStatic ...
      + camberGainSusp .* deltaSuspWheel ...
      + camberGainRoll .* phi;
```

说明：
- 这是概念设计阶段代理，不是完整悬架运动学

## 表格与 Excel 数据约定
### `table_struct`
推荐字段：
- `FyTable(alpha, Fz, gamma, Fy)`
- `MzTable(alpha, Fz, gamma, Mz)`
- `FxTable(kappa, Fz, gamma, Fx)`
- `Meta`

### `excel_file`
推荐 sheet：
- `FyTable`
- `MzTable`
- `FxTable`
- `Meta`

### 统一规则
- 列名缺失必须报错
- 数据点不足必须报错
- 内部统一转为 SI
- 不做隐式猜列名或 silent fallback

## 当前支持的轮胎工况
1. pure lateral
- `kappa = 0`
- 支持 `alpha` scan

2. pure longitudinal
- `alpha = 0`
- 支持 `kappa` scan

3. representative brake-in-turn
- `alpha ~= 0`
- `kappa < 0`
- 优先 combined 表；否则走 combined proxy

4. representative accel-out
- `alpha ~= 0`
- `kappa > 0`
- 规则同上

## combined proxy 边界
首版 `combined proxy` 的正式定位是：
- 只有 pure Fy/Fx 表时的工程近似
- 用于概念设计阶段 balance/utilization/peak margin 判断
- 不是完整 Magic Formula combined-slip

## 正式新增结果层
### `results.corners`
- `FzWheel`

### `results.tire`
- `forceModel`
- `inputs`
- `forces`
- `coeff`
- `balance`
- `validity`
- `scan`

关键字段：
- `results.tire.forces.Fx / Fy / Mz`
- `results.tire.coeff.muX / muY`
- `results.tire.balance.FyFrontTotal / FyRearTotal`
- `results.tire.balance.FxFrontTotal / FxRearTotal`
- `results.tire.balance.frontFyShare / rearFyShare`
- `results.tire.balance.balanceIndex`
- `results.tire.balance.peakMarginFront / peakMarginRear`
- `results.tire.validity.outOfRangeAny / contactLostAny / evalFailed`

### `results.flags`
- `tireForceModelEnabled`
- `tireEvalFailed`
- `tireOutOfRange`
- `contactLostAny`

### `run_batch summary`
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

## 新增函数
### `core/`
- `load_tire_table_data.m`
- `normalize_tire_operating_points.m`
- `evaluate_tire_table_model.m`
- `evaluate_tire_combined_proxy.m`
- `postprocess_tire_results.m`

### `config/`
- `build_demo_tire_force_tables.m`

### `main/`
- `demo_tire_table_pure_lateral.m`
- `demo_tire_table_brake_in_turn.m`

### `visualization/`
- `plot_tire_table_scan.m`

## 测试结论
本轮已新增并通过：
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

同时保留并通过全部既有 `V1.0.4` 测试。

## 当前仍未进入的内容
本轮没有进入：
- 完整瞬态 bicycle / yaw 闭环
- 通用 `.tir` parser
- 完整 Magic Formula 参数层
- 完整悬架外倾运动学
- 完整轮速 / 制动液压 / 驱动系统闭环

## 给下一线程的结论
1. 若继续做 `V1.5+`，优先在当前 `tire.forceModel / tireOp / results.tire` 接口上扩展，不要重写上层结构。
2. 若未来接入 `.tir`，应尽量只替换 adapter / evaluator 层，不要破坏现有 `run_case / run_batch` 与 `results.tire` 主接口。
3. 当前 `V1.5` 已可用于平台-轮胎-平衡的概念设计阶段筛选，但不要把它误写成完整操稳仿真器。
