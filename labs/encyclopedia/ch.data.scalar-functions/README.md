# 标量函数边界与故障实验

本实验保持四行输入，注入三类错误：

- 在目标时区转换前取 date，导致 UTC/上海跨日归错；
- 用 0 覆盖 NULL 温度，导致未测量被分类成真实数值；
- 期待 numeric 与 text 隐式相加，随后又遇到 `not-a-number`。

它还核对 CURRENT_TIMESTAMP/clock_timestamp 的时间边界和表达式索引的匹配/immutable 合同。运行 `./verify.sh`；所有结果来自固定离线预言，真实 PostgreSQL 仍未执行。
