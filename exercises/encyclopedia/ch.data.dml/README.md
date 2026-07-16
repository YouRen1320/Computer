# DML 独立练习（红色 starter）

修复 `answer.sql`：版本 UPDATE 使用 ID+version 并递增版本；DELETE 使用 D-03、RETIRED 与 NOT EXISTS；UPSERT 只更新 display_name/status/version；每条路径 RETURNING；保留 ROLLBACK。`./verify.sh` 仅在 starter 首先因缺版本保护被预期拒绝时成功。
