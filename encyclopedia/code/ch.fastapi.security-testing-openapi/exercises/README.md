# 练习：补回被遗漏的安全依赖

这个公开练习故意留下一个危险缺陷：代码虽然创建了 `HTTPBearer`，端点却没有把认证/授权依赖接入路由。因此匿名请求能够读取内部建议，生成的 OpenAPI 操作也没有安全要求。

先运行：

```bash
./verify.sh
```

当前脚本应稳定失败。你的任务是在不改断言的前提下完成：

1. 将 Bearer 凭据转换成当前主体；
2. 无凭据或无效凭据返回 `401`，并带 `WWW-Authenticate: Bearer`；
3. 要求 `suggestions:read` 权限，权限不足返回 `403`；
4. 让 OpenAPI 操作声明 `TrainingBearer` 安全要求；
5. 保留响应模型的字段过滤。

验收器会分别发送：无凭据、无效令牌、有效但无权限令牌、有效且有读取权限令牌；并检查
401/403/200、`WWW-Authenticate`、精确公开字段、`internal_score` 不泄漏，以及 OpenAPI
scheme/operation 安全声明。只实现“所有请求都拒绝”或只补 OpenAPI 不能通过。

这里只能使用固定教学令牌，不要在练习中接入或伪造外部 IdP 验证。FactoryCare 的生产认证仍由 Java 负责，Python 只消费经过内部边界传递和验证的身份上下文。
