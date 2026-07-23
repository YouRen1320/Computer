# 练习：修复响应数据泄露

路由返回的 repository 记录包含 `internal_secret`，当前 endpoint 没有声明公共响应模型。目标是只返回 `id`、`title`、`priority`，同时让 OpenAPI 响应指向明确 Schema。

先预测当前 JSON 和 OpenAPI，再运行 `./verify.sh`。公开初始版本必须稳定失败；不要通过修改断言接受 secret。
