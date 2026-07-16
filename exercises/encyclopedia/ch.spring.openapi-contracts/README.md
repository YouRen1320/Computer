# 修复漏报破坏性变化

starter 的 compatibility gate 无条件放行候选，因此删除响应必填字段 `version` 仍然通过。运行 `./verify.sh` 会稳定得到 2 个测试中的 1 个失败，哨兵为 `EXPECTED_BREAKING_CHANGE_BLOCKED`。

只修复 `CompatibilityGate.compatible`：旧 required 必须全部保留；新增 optional property 仍应通过。
