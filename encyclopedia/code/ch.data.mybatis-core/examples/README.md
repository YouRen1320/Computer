# MyBatis core 示例

这是一份离线可验证的 FactoryCare `WorkOrderMapper` 合同样例。它包含 Mapper 接口、record、XML、动态 SQL 输入矩阵和查询预算。

运行：

```sh
./verify.sh
```

验证器静态核对 namespace/id、`@Param`、`#{}`、constructor resultMap、动态标签和无嵌套 select，再用确定性渲染模型证明无筛选 SQL 合法、注入字符串只作为绑定值、三项 ids 产生三个参数槽。它没有加载 MyBatis、pgJDBC 或 PostgreSQL，不能替代 Boot 4.1 + Starter 4.1.0 的容器集成测试。
