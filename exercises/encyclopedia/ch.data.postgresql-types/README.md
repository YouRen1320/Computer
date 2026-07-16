# 练习：为设备事实选择 PostgreSQL 类型

当前 `answer.json` 是故意失败的 starter。执行 `./verify.sh` 应得到 `EXPECTED_RED`，证明失败来自把设备 ID 当普通文本，而不是 verifier 损坏。

修改六项决策，使核心关系仍由键和外键约束；为 UUID、JSONB、数组、domain/enum 边界写明约束；为每项选择补一条可执行的跨数据库迁移计划。完成答案必须能由 `oracle.rb answer.json` 输出 `postgresql-types-answer=PASS`。
