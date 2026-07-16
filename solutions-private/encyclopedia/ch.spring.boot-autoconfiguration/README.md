# 私有答案：类型化 back-off

答案在默认 Bean 方法增加 `@ConditionalOnMissingBean(AuditSink.class)`。用户实现存在时默认不注册，最终保持一个可注入候选。

运行 `./verify.sh` 应有两个测试通过。
