# MyBatis Repository 边界实验

实验用真实 MyBatis-Spring template 验证联合租户查询、保存、版本更新 0/1 行分类、Row 到领域映射、异常翻译和上层事务回滚。SQL 与框架类型只存在于 adapter。

唯一入口 `./verify.sh` 离线重放十一项断言。H2 不证明 PostgreSQL 18 的方言、隔离、锁、扩展类型或执行计划。
