# Repository 边界观察台

真实 `SqlSessionFactoryBean -> SqlSessionTemplate -> @Mapper -> adapter` 链把 H2 行重建为 FactoryCare 工单领域对象。端口不导入框架，所有 SQL 留在 adapter，并明确 empty、updated、not-found、version-conflict 与基础设施失败。

唯一入口 `./verify.sh` 在 JDK 25、Maven 3.9.16 下离线执行。H2 不是 PostgreSQL 18 方言、隔离或错误码证据。
