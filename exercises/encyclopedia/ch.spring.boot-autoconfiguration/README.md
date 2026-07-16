# 练习：让自动配置为用户 Bean back off

starter 故意遗漏 `@ConditionalOnMissingBean`，启用审计且应用提供数据库实现时会出现两个 `AuditSink`。运行 `./verify.sh` 应命中 `EXPECTED_SINGLE_AUDIT_SINK` 红灯。

只修自动配置的覆盖边界，不删除用户 Bean，也不启用全局名称覆盖。验证器接受确定性红灯或学习者修复后的全绿。
