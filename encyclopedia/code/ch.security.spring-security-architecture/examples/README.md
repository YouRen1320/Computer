# 两条安全链与异常翻译示例

纯 JDK 25 模型用合成请求演示：

- 高优先级链只公开精确的 `POST /api/v1/auth/login`；
- 第二条 catch-all 应用链保护其余 API 并拒绝未知路径；
- 只选择第一条匹配链；
- 未认证映射 401，已认证但缺 authority 映射 403；
- 每个请求结束都清理 ThreadLocal 安全上下文。

```bash
./verify.sh
```

模型不包含 Spring 类、真实 Session/JWT 或业务数据。它用于理解顺序预言；真实完成证据仍必须在 Boot 4.1 管理的 Spring Security 版本上运行容器集成测试。
