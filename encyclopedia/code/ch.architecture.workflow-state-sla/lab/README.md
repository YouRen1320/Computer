# 状态与 SLA 故障注入实验

验证器先重放安全基线，再逐个注入七个独立故障：

- `JUMP_ALLOWED`：允许 `CREATED → CLOSED` 跳跃；
- `MUTATE_BEFORE_VALIDATE`：验证失败前已修改状态；
- `GUARD_SKIPPED`：派单不要求 assignee；
- `TERMINAL_REVIVED`：教学终态被复活；
- `SYSTEM_CLOCK`：同一命令使用漂移的“现在”；
- `LOCAL_TIME_DEADLINE`：跨夏令时用 local time 计算连续时长；
- `PAUSE_DOUBLE_COUNT`：同一暂停区间重复延长 deadline。

```bash
./verify.sh
```

DST fixture 固定为 `America/New_York` 的 2026 年春季跳时，不读取机器默认时区。代码类型明确命名为 `DemoTicket`/`DemoTicketStatus`；五个同名状态映射到 FactoryCare canonical 状态，但省略其余七个状态和真实重开边，因此不替代唯一 12 状态或数据库事务测试。
