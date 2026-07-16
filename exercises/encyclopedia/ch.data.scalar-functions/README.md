# 标量函数独立练习（红色 starter）

修复 `answer.sql`：

- 保留五个原始字段；
- 规范化文本并正确处理空白 alias；
- numeric 舍入一位；
- CASE 首先保留 NULL→UNKNOWN；
- 先把 timestamptz 转成 Asia/Shanghai 墙钟，再 date_trunc/cast；
- 不依赖 numeric/text 隐式转换。

`./verify.sh` 只有在 starter 被 oracle 按预期拒绝时才成功。完成后可直接运行 `ruby oracle.rb answer.sql`。
