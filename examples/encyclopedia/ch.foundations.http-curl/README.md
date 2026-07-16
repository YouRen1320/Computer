# 示例：用 curl 对本地固定 HTTP 服务取证

本示例只在 `127.0.0.1` 上监听，不需要公网，不读取代理配置中的凭据，也不会接收真实账号、Token 或工单数据。服务器提供固定的 200、201、400/404/415、503 和慢响应端点。

一键验证：

```bash
ruby verify.rb
```

验证器启动随机回环端口，用系统 `curl` 分别保存响应 Header、Body 和 `%{http_code}`/`%{content_type}`/`%{time_total}`，再断言：

- 2xx、4xx、5xx 由 HTTP status 分类；
- 默认 curl 收完整的 404 或 503 时，传输退出码仍可为 0；
- JSON 只在响应 `Content-Type` 声明 JSON 媒体类型时解析；
- 错误请求 `Content-Type` 得到 415；
- `/slow` 在 0.10 秒预算下得到 curl 退出码 28、HTTP status `000` 和非空 stderr。

手动练习时先运行：

```bash
ruby server.rb
```

另开终端访问 `http://127.0.0.1:45678`。命令中加 `--noproxy "*"`，确保回环请求不经过用户代理。结束后在服务器终端按 Ctrl-C。
