# 跨租户隔离故障注入实验

本实验把租户约束放在认证上下文、查询、写入、缓存、后台任务、关联查询和全局目录七个边界上。数据均为离线合成数据；`TENANT-A` 与 `TENANT-B` 故意复用 `LOCAL-1`，用来暴露“只按业务 ID 查询”的错误。

运行：

```bash
./verify.sh
```

验证器先重放无故障基线，再逐个注入七种故障，并要求每种故障命中唯一标记：

- `TRUST_REQUEST_TENANT`：请求字段覆盖认证成员关系；
- `LIST_MISSING_TENANT`：列表漏掉租户谓词；
- `WRITE_BY_ID_ONLY`：写入只按局部 ID；
- `CACHE_KEY_MISSING_TENANT`：缓存键未含租户；
- `TASK_CONTEXT_MISSING`：后台任务未显式携带租户；
- `JOIN_TENANT_MISSING`：关联只比较局部 ID；
- `NULL_MEANS_GLOBAL`：把空租户误当作全局目录。

该实验验证应用层约束的可重放反例，不启动数据库、消息中间件或网络服务，也不声称覆盖连接池下 PostgreSQL RLS、真实 MyBatis 映射或 Spring Security 过滤器链。
