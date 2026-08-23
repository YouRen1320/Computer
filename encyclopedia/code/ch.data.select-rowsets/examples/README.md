# SELECT 行集：正确示例

这是纯离线示例。`query.sql` 是供阅读和未来 PostgreSQL 集成测试使用的 SQL；`oracle.rb` **不解析或执行 SQL**，只检查本任务的关键结构，再独立对固定 CSV 计算预言。

运行：

```sh
./verify.sh
```

PASS 只证明固定输入下的投影、过滤、排序、分页与 DISTINCT 预言一致，不证明真实 PostgreSQL 18 已接受该 SQL。
