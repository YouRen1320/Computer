# DDL 与约束可运行示例

`schema.sql` 在事务中重建两表并回滚，`cases.sql/json` 给出合法与五类非法插入。运行 `./verify.sh`；oracle 检查命名约束和依赖顺序，再独立执行约束模型，不连接 PostgreSQL。
