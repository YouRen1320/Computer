# 示例：一份可证伪的学习账本

`valid-ledger.yml` 记录一个窄范围学习主张，而不是笼统写“我会 SQL”。它同时包含：

- explain、build、diagnose 三类掌握证据；
- 固定输入、执行前预测、实际观察和未验证边界；
- 修复后的复跑结果；
- 1/3/7 天主动检索计划。

在本目录执行只读校验：

```text
ruby verify.rb valid-ledger.yml
```

预期最后一行是 `ledger verification: PASS`，退出状态为 0。该校验器只证明结构和固定示例预言满足规则，不能替代学习者的口头解释与独立构建。

可以先预测：删除 `boundary`、把 `artifact_exists` 当成掌握，或把复习日写成重复的 `1,1,1` 后，校验器应在哪一项失败。
