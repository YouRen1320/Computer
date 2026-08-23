# 独立练习：修复报修端验收包

公开 `answer.json` 故意存在合同、幂等、权限降级、状态和发布证据问题。只有字节完全一致的登记 starter 由 `./verify.sh` 返回 41 与 `EXPECTED_RED`；正确修复由同一命令返回 0 与 `EXERCISE_GREEN`，部分修改、未知失败或基础设施异常返回 43。只修改 `answer.json`，不要修改 oracle；离线绿灯不替代真机、后端、对象存储、断网恢复或发布 E2E。
