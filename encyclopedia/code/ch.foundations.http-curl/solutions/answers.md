# 隔离解析：HTTP 报文、方法、状态码、Header、Body 与 curl

完成公开练习并保存预测后再阅读。

## A 组

首行是状态行；随后三行是响应 Header；空行分隔元数据与 Body；最后一行是 JSON 表示。默认 curl 把“成功完成 HTTP 传输”和“HTTP status 是否为错误类”分开，完整收到 404 时退出码通常仍为 0，除非显式使用 `--fail` 或 `--fail-with-body` 等策略。响应 `Content-Type` 的基础媒体类型为 `application/problem+json`，允许先按 JSON 语法读取，再按问题详情契约解释字段。

## B 组

GET 常用于读取，POST 常用于让目标资源处理提交内容，PUT 常用于以给定表示创建/替换目标状态，PATCH 常用于部分修改，DELETE 请求移除关联。方法表达协议意图，最终结果仍由 status、响应字段、body 和后续可观察状态确认。创建请求至少应包含 POST、目标、`Content-Type: application/json` 与虚构 JSON body。

## C 组

1. HTTP status 503；若完整收到，默认 curl exit 可为 0；证据表明服务端返回了错误响应。
2. 没有 HTTP status，curl exit 28；status `000` 是 curl 输出占位，不是响应。
3. 没有 HTTP status，curl 常以名称解析相关非零退出码结束；应记录 stderr，不猜应用状态。
4. HTTP status 415；默认传输 exit 可为 0；服务端已经收到并拒绝请求表示格式。

## D 组

可组合 `--dump-header headers.txt --output body.bin --write-out '%{http_code} %{content_type} %{time_total}\n'`，并加 `--silent --show-error`。详细跟踪可能显示请求 Header；若其中含 Authorization、Cookie、签名或内部主机信息，直接提交会泄露秘密。应先脱敏且保留与问题相关的最小证据。

## E 组

不能仅凭首字符解析 JSON，应以媒体类型和契约为准；发送的字节像 JSON 不等于已经声明其媒体类型；`application/problem+json` 使用 JSON 语法，但错误对象字段契约不必与成功资源相同。

## F 组

最小证据包括时间、method、脱敏 URL/target、请求 `Content-Type`、是否带 body、HTTP status（若有）、响应 `Content-Type`、body 摘要、curl exit、stderr、超时预算与总耗时。先确认是否收到 HTTP 响应，再按 status 类别判断，随后按媒体类型读取 body。

## G 组伪代码

```text
执行 curl，分别保存 header/body/write-out/stderr/exit
如果 http_status == 000：按 curl exit 与 stderr 归类 DNS/TCP/TLS/timeout
否则：
  先按响应 Content-Type 选择 JSON 或原始文本读取器
  如果 status 在 400..499：client_contract_error
  如果 status 在 500..599：server_error
  如果 status 在 200..299：success
  其他：按契约处理重定向或信息响应
始终保留 curl exit，不能用它覆盖 HTTP 分类
```

关键不是把两套信号强行合并，而是保留“是否收到响应”和“响应表达什么”两个判断轴。
