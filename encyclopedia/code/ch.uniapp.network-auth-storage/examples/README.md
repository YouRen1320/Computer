# uni-app 网络、认证与存储示例

示例把宿主请求外层的稳定逻辑做成可离线验证模块：环境 allowlist、HTTP 状态映射、认证状态、版本化草稿和日志允许列表。

```bash
./verify.sh
```

验证器使用 fake transport/storage；未调用 `uni.request`、真实白名单、TLS、OIDC、平台安全存储或 FactoryCare 服务。
