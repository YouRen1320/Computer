# 实验记录单

对每个故障记录：失败阶段、第一条可信证据、最小修复、原命令重跑结果、未覆盖的真实环境。

| 故障 | 失败阶段 | 第一证据 | 修复方向 |
|---|---|---|---|
| `wrong-macro` | 编译/产物 | 微信目标缺少 `weixin-adapter` | 修正允许宏并重建两个目标 |
| `build-only` | 运行验证 | `branchHits` 没有微信分支 | 执行目标×能力矩阵 |
| `missing-fallback` | 运行合同 | unsupported 没有恢复动作 | 返回稳定 fallback |
