# 修复漏报破坏性变化
+
## 同一验证入口的状态合同

只修改 README 指定的 `src/main` 可编辑 starter，测试、POM 与验证器保持不变，然后每次都运行 `./verify.sh`。

- `0` + `EXERCISE_GREEN`：登记的测试数量全部通过，状态为 `completed`；
- `41` + `EXPECTED_RED`：测试数量、唯一失败数和本章 sentinel 精确匹配公开 starter；
- `43`：编译、依赖、测试数量、失败形状或工具环境不在上述两种已知状态，必须先读日志诊断。

离线绿灯只覆盖本练习登记的合同；涉及 PostgreSQL/Testcontainers 的章节仍需正文或 lab 明示的真实环境证据。

starter 的 compatibility gate 无条件放行候选，因此删除响应必填字段 `version` 仍然通过。运行 `./verify.sh` 会稳定得到 2 个测试中的 1 个失败，哨兵为 `EXPECTED_BREAKING_CHANGE_BLOCKED`。

只修复 `CompatibilityGate.compatible`：旧 required 必须全部保留；新增 optional property 仍应通过。
