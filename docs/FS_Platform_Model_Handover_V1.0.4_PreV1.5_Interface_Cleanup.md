# FS Platform Model 交接文档（V1.0.4｜Pre-V1.5 Interface Cleanup）

## 文档用途
本文件用于记录本轮“进入 V1.5 前的接口清洁型修订”。
它不是新的大版本说明，也不是 V1.5 开发文档，而是在当前 `V1.0.4` 稳定主链基础上，对标准 case 与正式接口做一次定点清理，避免后续 V1.5 开发继续被隐式默认值与旧字段残留干扰。

项目路径：
- 项目根目录：`E:\JX Areo adaption\fs_platform_model`
- 本文档路径：`E:\JX Areo adaption\fs_platform_model\docs\FS_Platform_Model_Handover_V1.0.4_PreV1.5_Interface_Cleanup.md`

## 本次修订的定位
本次修订不是：
- 重建项目
- 进入 V1.5 轮胎代理层开发
- 引入新的自由度或新的主求解器
- 回退到 bump/droop 主受力写法

本次修订只做三件事：
1. 让标准 case 尽量显式完整，不再依赖 autofill warning 才成立
2. 让标准轮胎输入正式统一到 `tire.*`，不再正式使用 `sus.kt`
3. 让 baseline / target / demo 作为正式案例在正常运行时保持 warning 清洁

## 版本继承关系（不变）
1. `V1.0`
- 三自由度准静态平台模型主链：`q = [z; theta; phi]`
- `run_case / run_batch` 单入口
- 统一 `caseDef / results` 结构

2. `V1.0.1`
- 删除 bump/droop 主求解力
- shock eye-to-eye 三长度成为正式输入
- shock / wheel 行程转为后处理约束判据

3. `V1.0.3a`
- `tire.mode`
- `rules / targets / feasible` 分层
- `static / dynamic clearance` 拆分
- `effective travel` 双重验证
- deprecated / autofill warning 输出机制

4. `V1.0.4`
- spring sweep map
- bump-adjusted scrape map
- `run_batch` summary 与测试体系稳定通过

5. 本次修订
- 不改变以上主线
- 只做标准接口清洁，为后续 V1.5 打底

## 当前仍然必须保持不变的骨架
### 主目录结构
- `main/`
- `config/`
- `core/`
- `aero/`
- `utils/`
- `visualization/`
- `tests/`
- `data/`
- `docs/`

### 主流程
`run_case`
-> `default_solver_options`
-> `validate_case_struct`
-> `preprocess_case`
-> `solve_equilibrium`
-> `postprocess_results`

### 状态定义
- `q = [z; theta; phi]`
- `z > 0`：车身下沉
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾
- `ay > 0`：左转

### 仍保留的当前物理语义
- `static / dynamic clearance` 分层
- `rules / targets / feasible` 分层
- `deltaGround / deltaSuspWheel / deltaTire / shockStroke / deltaReconError`
- shock 三长度输入链
- `tire.mode = off / fixed / range`

## 本次到底改了什么
### 1. 标准 case 显式化
标准 case 现在优先显式给出当前活跃字段，而不是依赖 `validate_case_struct` 的 autofill warning 才成立。

本轮已清理的正式 case：
- `build_case_2025_baseline`
- `build_case_2026_target`
- `demo_case_2026`
- `demo_spring_sweep_map` 生成出的 sweep case

具体做法：
- 在标准 case 中显式给出 `veh.lf / veh.lr`
- 在标准 case 中显式回写 `sus.kw = ks .* mr.^2`
- 不再把 `sus.kt` 写入 baseline / target 的正式输入

### 2. 正式轮胎输入迁移到 tire.*
当前正式轮胎输入语义已经统一到：
- `caseDef.tire.mode`
- `caseDef.tire.ktFront`
- `caseDef.tire.ktRear`
- `caseDef.tire.ktFrontRange`
- `caseDef.tire.ktRearRange`

当前结论：
- `sus.kt` 只保留 backward compatibility
- 标准 case 不应再写非空 `sus.kt`
- 后续线程若新增标准 case，也应默认从 `tire.*` 进入

### 3. warning 机制保留，但标准 case 不再依赖它
`validate_case_struct` 当前仍保留三类 warning：
1. autofill warning
2. deprecated warning
3. shock/wheel consistency warning

但本次修订后的正式定位是：
- 它们主要服务于旧 case 兼容与异常输入暴露
- 不是标准 case 的正常运行前提

因此：
- baseline / target / demo 正常运行时，不应再出现 autofill warning
- baseline / target / demo 正常运行时，不应再出现 `caseDef.sus.kt is deprecated`
- baseline / target / demo 正常运行时，不应再带 shock/wheel consistency warning

### 4. autofill warning 的统计口径做了清洁化处理
保留了 `ensure_fields` 与 `local_default_case` 兼容机制，但对 autofill warning 的统计口径进行了清理：
- 对兼容层专用空默认字段，不再把它们计入标准 case 的 autofill warning
- 当前过滤对象包括：
  - `sus.kt`
  - `sus.kBump`
  - `sus.bumpGap`
  - `sus.kDroop`
  - `sus.droopGap`

说明：
- 这不是删除兼容层
- 这是避免兼容层占位字段继续污染标准 case warning
- 真正的活跃字段缺失仍然会触发 autofill warning

### 5. `preprocess_case` 的旧字段 fallback 被修正
在 `tire.mode='fixed'` 的解析里：
- 只有当旧 case 真提供了非空 `sus.kt` 时，才允许把它作为 fallback
- 避免标准 case 已经清掉 `sus.kt` 后，兼容分支仍然误索引空字段

### 6. spring sweep 生成 case 也同步清洁
`build_spring_sweep_cases` 之前会把 `sus.kw` 清空，导致 sweep 生成 case 仍触发 `Auto-filled missing fields: 1`。
本轮已改为：
- 直接显式回写 `sus.kw = ks .* mr.^2`

结果：
- `demo_spring_sweep_map`
- `test_demo_spring_sweep_map_runs`

现在也不再因为 `sus.kw` 为空而产生多余 autofill warning。

## 本轮修改文件
### 配置与标准 case
- `config/build_case_2025_baseline.m`
- `config/build_case_2026_target.m`

### 主流程与兼容层
- `core/validate_case_struct.m`
- `core/preprocess_case.m`

### demo 与 sweep 工具
- `main/demo_case_2026.m`
- `main/demo_spring_sweep_map.m`
- `utils/build_spring_sweep_cases.m`

### 文档
- `README.md`
- `docs/FS_Platform_Model_Handover_V1.0_to_V1.0.4.md`
- `docs/FS_Platform_Model_CrossThread_Handover_Summary_V1.0.4.md`
- 本文档

## 本轮新增测试
1. `test_standard_case_no_autofill_warning`
- 验证标准 baseline / target case 不再触发 autofill warning

2. `test_standard_case_no_sus_kt_deprecated_warning`
- 验证标准 baseline / target case 不再触发 `sus.kt` deprecated warning

3. `test_standard_case_no_shock_wheel_consistency_warning`
- 验证标准 baseline / target case 不再触发 shock/wheel consistency warning

4. `test_demo_case_no_interface_cleanup_warning`
- 验证正式 demo 不再触发 autofill / `sus.kt` deprecated warning

## 保留但必须继续通过的旧测试
这些测试本轮没有删除，也不应该被“清理 warning”逻辑绕过：
- `test_validation_warnings_emit`
- `test_shock_wheel_consistency_warning`
- `test_effective_travel_rule_check`
- `test_effective_jounce_rule_check`
- `test_range_results_inputs_consistency`
- `test_run_batch_summary_fields_v103a`
- `test_run_batch_summary_fields_v104`
- 以及其余 V1.0.4 回归测试

这意味着：
- 兼容机制仍然存在
- 旧字段 warning 仍然可被异常 case 正确触发
- 本次修订没有通过“关闭 warning 机制”来伪造清洁结果

## 本轮验证结论
### 1. 标准 case / demo 的接口清洁结论
以下对象在正常运行下已实现：
- 不再出现 `Auto-filled missing fields`
- 不再出现 `caseDef.sus.kt is deprecated`
- 不再出现 shock/wheel consistency warning

对象包括：
- `build_case_2025_baseline`
- `build_case_2026_target`
- `demo_case_2026`
- `demo_spring_sweep_map` 生成的 sweep case

### 2. 回归状态
- V1.0.4 全量旧测试继续通过
- 本轮新增 4 项接口清洁测试通过

### 3. 静态检查
- `checkcode` 已通过
- `TOTAL_CHECKCODE_MESSAGES=0`

## 当前接口清洁后的结论（给下一线程）
### 正式标准输入
如果下一线程要新增或修改标准 case，应默认遵循：
- `veh / sus / tire / rules / targets / ref / man / solver` 活跃字段尽量显式给出
- 标准轮胎输入写入 `tire.*`
- 不再把 `sus.kt` 作为正式输入
- 不要让标准 case 依赖 autofill warning 才成立

### 兼容层输入
如果下一线程要处理旧 case，可以继续依赖：
- `sus.kt` 的 deprecated 兼容路径
- autofill warning
- consistency warning

但这些路径只应服务于：
- backward compatibility
- 异常测试
- 输入歧义暴露

不应重新主导正式 case。

## 当前仍未进入的内容
本次没有进入：
- V1.5 的 tire load sensitivity
- grip / balance proxy
- brake-in-turn / accel-out 轮胎扫描
- 新的轮胎结果层
- V2.0 的 transient bicycle / ride 模型

## 推荐下一步
如果下一线程正式进入 V1.5，建议把本轮修订当作清洁基线：
1. 标准 case 继续坚持 `tire.*` 正式输入
2. 兼容层只保留，不扩张
3. 在此基础上再讨论轮胎代理层新增字段与结果层，而不是把旧 `sus.kt` 重新拉回主线

## 本文档校验记录
本文档形成前已回查：
1. 标准 case 当前是否已去除 `sus.kt` 正式使用
2. 标准 case 当前是否已消除 autofill warning
3. 标准 case 当前是否已消除 shock/wheel consistency warning
4. 兼容 warning 测试是否仍然保留并通过
5. `demo_spring_sweep_map` 生成 case 是否仍会产生 `sus.kw` 相关 autofill warning
6. `README / docs / tests / 代码注释` 是否已与当前正式接口结论一致
