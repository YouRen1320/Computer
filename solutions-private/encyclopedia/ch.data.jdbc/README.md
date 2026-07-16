# 私有参考解

参考合同使用 PreparedStatement 参数槽、可空 Long 与 OffsetDateTime、显式空结果和完整资源关闭；多语句使用同一 Connection，失败 rollback；23505 翻译冲突，40001/40P01 整事务重试，并保留 SQLException cause。

执行 `./verify.sh` 应通过。该答案不替代 JDK/pgJDBC/PostgreSQL 集成测试。
