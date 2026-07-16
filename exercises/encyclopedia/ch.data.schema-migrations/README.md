# 练习：恢复安全迁移序列

当前 `answer.json` 故意改写已应用 V1。执行 `./verify.sh` 应得到 `EXPECTED_RED`。

修复时恢复原 checksum，使用 create/expand/backfill/validate/contract，证明空库与升级库指纹一致、第二次 migrate 无 pending、失败不标成功，并以新 forward-fix 恢复；旧应用完全退场后才能 contract。
