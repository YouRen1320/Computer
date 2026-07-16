# 故障观察表

对每个场景填写四项：

| 场景 | 用户可见影响 | 哪条证据先变红 | 最小修复 | 原预言如何重跑 |
|---|---|---|---|---|
| log-missing-trace |  |  |  |  |
| metric-high-cardinality |  |  |  |  |
| async-trace-break |  |  |  |  |
| liveness-external-dependency |  |  |  |  |
| sli-denominator-omits-system-errors |  |  |  |  |
| transient-spike-pages |  |  |  |  |

加问：Python AI 是可选依赖时，它超时应改变哪一个功能 SLI、哪一个 dependency health？为什么不应改变核心 API liveness？
