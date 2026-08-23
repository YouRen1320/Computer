# JDBC 边界示例

`JdbcWorkOrderRepository.java` 展示基础 `DataSource`、参数化查询、显式 ResultSet 映射、try-with-resources 和事务 commit/rollback；`cases.json` 固定正常、空结果、注入字符和事务失败证据。

执行 `./verify.sh` 仅检查源码合同与离线状态，不编译 Java、不加载 pgJDBC、不连接 PostgreSQL；真实 T3 集成仍未验证。
