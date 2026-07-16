# FilterChain 与 SecurityContext 故障实验

实验以两条有序链、ThreadLocal context 和固定状态翻译器重放 Spring Security 架构不变量。

```bash
./verify.sh
```

六个命名故障分别证明：

- `WIDE_MATCHER_FIRST`：宽 public matcher 抢先匹配受保护 API；
- `ANONYMOUS_DEFAULT_ALLOW`：应用链匿名默认放行；
- `FILTER_ORDER`：授权先于认证上下文建立；
- `NO_CATCH_ALL`：未知路径没有受保护链；
- `CONTEXT_NOT_CLEARED`：请求结束保留旧身份；
- `WRONG_EXCEPTION_MAPPING`：未认证错误被写成 403。

每个 fault 必须非零退出并命中第一处稳定 marker。此资产没有 Spring 依赖，不能替代真实 `FilterChainProxy`/Servlet 容器测试。
