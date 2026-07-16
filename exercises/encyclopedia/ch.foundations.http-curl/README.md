# 练习：HTTP 报文、状态码、Header、Body 与 curl

先完成预测和命令设计，再查看隔离解析。所有示例 URL 仅作文本分析；实际操作只用本章回环服务器。

## A. 报文阅读

给定：

```text
HTTP/1.1 404 Not Found
Content-Type: application/problem+json; charset=utf-8
Content-Length: 62

{"code":"work-order-not-found","detail":"FC-9999 is absent"}
```

1. 标出状态行、Header 区、空行和 Body。
2. `curl` 若完整收到它，默认退出码是否必然非零？
3. 客户端应以什么证据决定按 JSON 解析？

## B. 方法与意图

比较 GET、POST、PUT、PATCH、DELETE 的常见意图，但说明“方法名”为什么不能单独证明服务端已经完成业务动作。为“创建工单”写一条 POST 请求，包含明确的请求 `Content-Type`，且不使用真实凭据。

## C. 两类错误

分别为下列情况写出 HTTP status、curl exit 与证据边界：

1. 收到 503 文本响应，传输完整；
2. 0.10 秒超时，未收到响应状态行；
3. DNS 失败；
4. 收到 415，指出请求媒体类型不受支持。

## D. curl 取证命令

设计一条命令，把 header 与 body 分开保存，并在终端只输出 status、响应媒体类型和总耗时。解释为什么不应把 `-v` 输出和 Authorization 一起提交到工单。

## E. Content-Type 反例

1. Body 看起来以 `{` 开头，但响应是 `text/plain`，应不应该无条件 JSON.parse？
2. 请求发送 JSON 字符串但未声明 `Content-Type: application/json`，服务端为何可返回 415？
3. 响应为 `application/problem+json`，能否按 JSON 语法读取？业务字段是否必然与成功响应相同？

## F. FactoryCare 调试

前端说“创建失败”，只提供了一段红色 body。你需要向其索取哪些最小证据，才能区分 4xx、5xx 与传输失败？写出字段清单与诊断顺序。

## G. 需求变更

现有脚本只在 curl exit 非零时报警。新要求是：4xx 记客户端契约错误、5xx 记服务端错误、无 HTTP 响应记传输错误，同时保留 JSON/文本 body。设计判定伪代码，明确先看什么、后看什么。

## H. 无 AI 训练

关闭 AI，限时 40 分钟完成 A—G。随后手动运行 200、404、503、415 与 timeout 五个请求，保留预测、stdout、stderr、退出码和修复复跑。不得查看私有解析后再补写预测。
