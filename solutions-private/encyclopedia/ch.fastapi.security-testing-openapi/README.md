# 私有参考解：接入认证、权限和 OpenAPI 安全声明

参考解通过 `Security(HTTPBearer)` 建立主体，再由依赖检查 `suggestions:read` 权限。公开响应使用 `response_model`，内部评分不会泄漏；同一个依赖图还会把 Bearer 方案写入 OpenAPI。

运行：

```bash
./verify.sh
```

脚本只执行本地进程内验证。固定令牌不是生产认证实现，也没有验证 OAuth/OIDC、JWT/JWKS、外部 IdP、代理头或服务间 mTLS。真实 FactoryCare 认证与业务授权仍由 Java 统一拥有。
