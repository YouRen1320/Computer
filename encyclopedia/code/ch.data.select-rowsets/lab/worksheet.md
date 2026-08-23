# Worksheet

在运行 oracle 前先写下预测：

| 检查 | 你的预测 | 观察 | 修复 |
| --- | --- | --- | --- |
| 合格行完整顺序 |  |  |  |
| category=unknown（空集） |  |  |  |
| category=compressor（单行） |  |  |  |
| category=pump（多行） |  |  |  |
| retired_at 为 NULL 的合格行 |  |  |  |
| `= NULL` 结果 |  |  |  |
| 缺括号泄漏的行 |  |  |  |
| 非唯一分页重复/遗漏 |  |  |  |

最后解释：为什么“固定数据 + 全序”可以证明本实验稳定，却不能证明并发插入期间的 offset 分页稳定？
