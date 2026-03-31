# FS Platform Model 交接文档（V1.5.0a｜Aero Parser / Debug Fix）

## 文档用途
本文件用于记录 `V1.5.0a` 的一次阻塞级基础修复。

这次修改不是继续扩展 `V1.5` 的轮胎能力边界，而是先修复一个更前置的基础阻塞：
- `demo_tire_table_pure_lateral`
- `demo_tire_table_brake_in_turn`

两者在进入轮胎代理层之前，就会在气动插值层 `aero/interp_aero_map.m` 报错并中断。  
因此，本轮工作的目标是恢复 `V1.5` 主链可运行性，并把这一轮修复沉淀成后续线程可以直接复用的事实来源。

当前时间基准：
- 形成日期：`2026-03-21`
- 当前工程基线：`V1.5.0a`

## 本次任务的最终结论
本次修改已经完成一次**阻塞级 parser/debug 修复**：

1. 修复了 `aero/interp_aero_map.m` 的解析/兼容性阻塞问题；
2. 保留了 4D 气动 map 的物理功能、clamp 逻辑、nearest fallback 逻辑、透明 flag 逻辑；
3. 保持了 `run_case -> validate -> preprocess -> solve -> postprocess` 主链不变；
4. 保持了 `V1.5` 轮胎代理层“平台后评估层”的边界不变；
5. 让两个 `V1.5` demo 至少能够真正通过 aero map 层并进入 tire layer。

本次修复点位于：
- `aero/interp_aero_map.m`

而不是：
- `tire.forceModel`
- `tireOp`
- `results.tire`

这点必须明确，因为本轮问题的根源不是 `V1.5` 轮胎表格代理本体，而是更前置的气动插值层 parser/兼容性错误。

## 问题来源与阻塞链
本轮修复前，两个 demo 的真实阻塞链为：

```matlab
demo_tire_table_*
-> run_case
-> solve_equilibrium
-> residual_equilibrium
-> calc_external_loads
-> calc_aero_state
-> interp_aero_map
```

报错现象为：
- 文件：`aero/interp_aero_map.m`
- 报错：`非法使用保留关键字 "end"`

本次排查后确认，阻塞原因不是单纯的物理逻辑错误，而是两类兼容性风险叠加：

1. 文件头部存在异常字符污染，导致首行实际变成 `ifunction ...`
2. 文件底部仍保留 local helper function，在更保守的 MATLAB 解析环境中提高了 parser 风险

因此，本轮正式修复策略不是“改一点点字符串”，而是将该文件整体收口为更保守、更透明的单主函数写法。

## 本次修复的核心设计决策
### 1. `interp_aero_map.m` 改为单主函数文件
本轮已将：
- 文件头部异常字符污染移除
- 文件底部 local helper function 全部移除

当前 `interp_aero_map.m` 只保留一个主函数定义：

```matlab
function aeroOut = interp_aero_map(mapData, hf, hr, phi, beta, options)
```

这样做的目的不是重写功能，而是降低以下风险：
- MATLAB 版本差异下的 parser 差异
- 文件编码/隐藏字符导致的解析异常
- “报错指向 `end`，但实际是文件结构或首行污染”这类难排查问题

### 2. 保留 4D 气动 map 功能，不用常数占位绕过
本轮没有删除气动 map，也没有把查询结果硬写死为常数。

当前仍然按以下 4 个维度做插值：
- `hf`
- `hr`
- `phi`
- `beta`

仍然继续读取：
- `hfGrid`
- `hrGrid`
- `phiGrid`
- `betaGrid`
- `CzTable`
- `CdTable`
- `frontShareTable`

若这些必需字段缺失，当前实现会明确报错，不做 silent fallback。

### 3. clamp 逻辑保留且继续透明输出
当前仍对查询点执行边界钳制：
- `hf`
- `hr`
- `phi`
- `beta`

并继续显式输出：
- `mapClampedAny`
- `mapClamped`
- `hfClamped`
- `hrClamped`
- `phiClamped`
- `betaClamped`
- `mapClampInfo`

这意味着：
- 本轮没有把气动插值改成“悄悄截断”
- 仍然保留了越界查询的透明工程追踪能力

### 4. linear -> nearest fallback 逻辑保留
当前逻辑保持为：

1. 优先尝试 `linear`
2. 若 `linear` 抛错，且 `allowFallback=true`，回退到 `nearest`
3. 若 `linear` 返回非有限值，且 `allowFallback=true`，同样回退到 `nearest`
4. 若 `allowFallback=false`，则直接报错
5. `fallbackReason` 继续写入 `mapClampInfo`

这延续了 `V1.0.3 / V1.0.4 / V1.5` 的透明 flag 思路，而不是把插值失败吞掉。

### 5. `pitchMomentTable` 继续可选
当前行为保持为：
- 若 `mapData.pitchMomentTable` 存在且非空，则参与插值
- 否则 `pitchMomentExtra = 0.0`

因此，本轮没有把 `pitchMomentTable` 升级成强制依赖字段，也没有因为缺少该表而让整条气动链报错。

### 6. 对调用链只做最小兼容同步
本轮只对 `core/calc_aero_state.m` 做了最小同步：
- 继续按原接口调用 `interp_aero_map`
- 优先读新字段
- 若后续仍有旧兼容字段名，保留最小回退逻辑

本轮没有改动：
- `core/calc_external_loads.m` 的外部接口
- `run_case`
- `solve_equilibrium`
- `postprocess_results`
- `V1.5` tire layer 的接口与边界

## 本次修改文件
### 核心修复
- `aero/interp_aero_map.m`

### 最小调用链同步
- `core/calc_aero_state.m`

### 相关测试修订
- `tests/test_aero_map_flags.m`

### 本轮新增测试
- `tests/test_interp_aero_map_basic.m`
- `tests/test_interp_aero_map_clamp_flags.m`
- `tests/test_interp_aero_map_no_pitch_table.m`
- `tests/test_interp_aero_map_fallback_nearest.m`

### 编码清理涉及文件
- `aero/interp_aero_map.m`
- `core/calc_aero_state.m`
- `core/calc_external_loads.m`
- `main/demo_tire_table_pure_lateral.m`
- `main/demo_tire_table_brake_in_turn.m`
- 本轮新增测试文件

## 本次对实现边界的明确说明
### 本轮没有做的事
本轮没有进入，也不应在后续交接中误写成“已完成”的内容：
- 重建项目
- 修改目录结构
- 改写主平衡方程
- 把轮胎力代理层塞回主求解链
- 删除气动 map
- 删除 `beta / phi` 输入
- 把气动项改成常数占位
- 重写 `results.tire`
- 重写 `run_case / run_batch` 主接口

### 本轮真正做的事
本轮真正做的是：
- 把 `interp_aero_map` 收口成更稳健的单主函数文件
- 修复 parser/编码层阻塞
- 保留原有物理语义与透明 flag 语义
- 增加最小但直接有效的 aero 插值回归测试

## 本次验证结果
### 新增并通过的气动插值层测试
1. `test_interp_aero_map_basic`
- 验证 4D linear 插值可正常返回
- 验证输出字段完整

2. `test_interp_aero_map_clamp_flags`
- 验证越界查询触发 clamp flag
- 验证 `mapClampInfo` 合理

3. `test_interp_aero_map_no_pitch_table`
- 验证缺少 `pitchMomentTable` 时仍可运行
- 验证 `pitchMomentExtra = 0`

4. `test_interp_aero_map_fallback_nearest`
- 构造 linear 非有限值场景
- 验证 `allowFallback=true` 时回退到 `nearest`
- 验证 `interpFallbackUsed=true`

### 既有相关测试
以下测试已继续通过：
- `test_aero_map_flags`
- `test_demo_tire_table_pure_lateral_runs`
- `test_demo_tire_table_brake_in_turn_runs`
- `test_demo_spring_sweep_map_runs`

### demo 运行结果
1. `demo_tire_table_pure_lateral`
- 已通过 aero map 原阻塞点
- 已进入 tire layer
- `results.flags.tireForceModelEnabled = true`
- `results.flags.tireEvalFailed = false`

2. `demo_tire_table_brake_in_turn`
- 已通过 aero map 原阻塞点
- 已进入 tire layer
- `results.flags.tireForceModelEnabled = true`
- `results.flags.tireEvalFailed = false`

### 当前已知非阻塞 warning
两个 demo 当前可能出现：
- `evaluate_tire_table_model:OutOfRange`

这表示轮胎表查询发生 clamp，是当前示例数据覆盖范围问题，不是本轮新的阻塞级错误。  
因此，本轮交付结论应为：
- aero parser blocker 已修复
- demo 已进入 tire layer
- 当前残留的是非阻塞 warning，不是 parser 级中断

## 编码与运行时目录说明
本轮排障过程中，曾临时生成工作区内运行时目录用于隔离 MATLAB 启动环境，例如：
- `.matlab_env`
- `.matlab_prefs`
- `.tmp`

这些目录不是项目源码，不属于正式版本内容，也不应被打包进发布 zip。  
本次交接结论里应明确区分：

1. **源码层更新**
- `interp_aero_map` parser/debug fix
- 最小调用链同步
- 新增测试

2. **运行时产物**
- `.matlab_*` 类目录
- MathWorks `ServiceHost` 缓存
- 临时日志与偏好文件

后续若重新打包版本，必须排除这些运行时目录，否则会把包体积异常放大。

## 给下一线程的直接结论
1. 当前 `V1.5.0a` 的这次修复属于**阻塞级基础修复**，不是功能扩展版。
2. 当前主要问题点已经从“aero parser 阻塞”推进为“轮胎表示例数据的 out-of-range warning 收口”。
3. 若继续做 `V1.5.x`，建议优先顺序如下：
- 优化示例 tire table 覆盖范围或 scan 设定，降低非阻塞 out-of-range warning
- 继续保持 `interp_aero_map` 的单主函数写法，不要重新引入尾部 local helper
- 若未来再改气动插值层，应继续保留 clamp/fallback/flag 透明语义

## 一句话总结
**本轮已在不改变三自由度准静态平台模型骨架、不改变 `V1.5` tire layer 边界的前提下，修复 `aero/interp_aero_map.m` 的 parser/兼容性阻塞问题，恢复 `V1.5.0a` demo 穿过 aero map 并进入 tire layer 的可运行性。**
