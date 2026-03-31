# caseDef 模板说明（V1.0.2）

## 角点顺序（固定）
1. FL
2. FR
3. RL
4. RR

## 单位与符号
- 全部 SI 单位
- `z > 0`：车身向下压缩
- `theta > 0`：车头下俯
- `phi > 0`：车身向右侧倾

## 必填顶层字段
- `meta`, `veh`, `sus`, `longi`, `aero`, `ref`, `man`, `solver`

## `sus` 必要字段（V1.0.2）
- `ks`, `mr`, `kw`
- `jounceMax`, `droopMax`
- `kArbF`, `kArbR`
- `shockLenExtended`, `shockLenCompressed`, `shockLenStatic`

## 兼容字段
- `kt`：deprecated，仅兼容保留，不参与主平衡
- `kBump`, `bumpGap`, `kDroop`, `droopGap`：deprecated，忽略

## 关键提醒
- `veh.lf + veh.lr = veh.L`
- 若 `lf/lr` 留空，则由 `L` 与 `wf_static` 自动反算
- `kw` 留空时由 `kw = ks * mr^2` 自动计算
- V1.0.2 中主平衡刚度定义：`keq = kw`
- `shockLen*` 支持标量或四角点数组 `[FL FR RL RR]`
- 每个角点必须满足：
  - `shockLenExtended > shockLenStatic > shockLenCompressed`

## 版本变化说明
- V1.0.2 在 V1.0.1 基础上继续修订：
  - bump/droop 继续停用
  - kt 不再参与主平衡
  - 统一为悬架-气动平台模型
