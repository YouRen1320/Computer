# FastAPI 安全、测试与 OpenAPI：最小闭环示例

这个示例演示一条可以在本地重复验证的链路：Bearer 凭据先被解析为 `Principal`，权限依赖再完成操作级授权，端点最后执行租户级资源授权；同一份 FastAPI 路由还会生成可检查的 OpenAPI 安全声明。

运行：

```bash
./verify.sh
```

验证脚本只使用进程内 `TestClient` 和固定教学令牌，不访问网络，也没有验证真实 OAuth/OIDC、JWT 签名、密钥轮换或外部身份提供商。`training-reader`、`training-denied` 和 `training-expired` 都是假数据，绝不能复制到生产配置。

FactoryCare 的正式边界仍然是：客户端只调用 Java；Java 拥有登录、令牌签发、权限、租户与业务状态；FastAPI 只暴露受保护的内部 AI/派生能力，不能成为第二套业务后端。
