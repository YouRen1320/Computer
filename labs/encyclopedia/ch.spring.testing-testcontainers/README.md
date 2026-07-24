# PostgreSQL 18 容器集成实验

实验让一个测试类共享唯一的 `static @Container` PostgreSQL 18。Flyway 先执行真实迁移，`JdbcWorkOrders` 再执行租户查询、唯一约束与乐观锁 SQL；最后用一个小型 Spring context 验证同一个 DataSource 的装配。它不依赖本机固定端口、数据库名或预置账号。

前置条件：Docker daemon 可用，并已允许首次拉取 `postgres:18` 与 Testcontainers 清理容器。Maven 依赖预热后运行 `./verify.sh`；真实容器路径的固定结果为 8 个测试通过。Docker 不可用时 verifier 只做离线编译与静态合同检查，并明确输出 `UNVERIFIED`；该绿色静态结果绝不能表述为 PostgreSQL、Flyway 或容器集成已经验证。
