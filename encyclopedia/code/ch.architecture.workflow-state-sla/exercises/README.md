# 状态与 SLA 独立练习

修复 `src/WorkflowStateSlaChallenge.java` 中七个 `TODO`：允许边、guard、非法转换不变、教学终态、基础 deadline、暂停恢复与固定 Clock 超时边界。

```bash
./verify.sh
```

起始代码必须稳定失败，首个标记为 `JUMP_STATE_ACCEPTED`。不要删除负向断言。`DemoTicketStatus` 是教学投影：五个同名值映射 FactoryCare canonical 状态，但省略其余七个状态和真实重开边；这里的 CLOSED 终态不能冒充 FactoryCare `WorkOrder` 规则，正式项目保留合法 `CLOSED → REOPENED`。
