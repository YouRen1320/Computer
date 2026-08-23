# 练习：让自动配置为用户 Bean back off
+
## 同一验证入口的状态合同

只修改 README 指定的 `src/main` 可编辑 starter，测试、POM 与验证器保持不变，然后每次都运行 `./verify.sh`。

- `0` + `EXERCISE_GREEN`：登记的测试数量全部通过，状态为 `completed`；
- `41` + `EXPECTED_RED`：测试数量、唯一失败数和本章 sentinel 精确匹配公开 starter；
- `43`：编译、依赖、测试数量、失败形状或工具环境不在上述两种已知状态，必须先读日志诊断。

离线绿灯只覆盖本练习登记的合同；涉及 PostgreSQL/Testcontainers 的章节仍需正文或 lab 明示的真实环境证据。

starter 故意遗漏 `@ConditionalOnMissingBean`，启用审计且应用提供数据库实现时会出现两个 `AuditSink`。运行 `./verify.sh` 应命中 `EXPECTED_SINGLE_AUDIT_SINK` 红灯。

只修自动配置的覆盖边界，不删除用户 Bean，也不启用全局名称覆盖。验证器接受确定性红灯或学习者修复后的全绿。
