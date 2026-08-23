# 实验：建立 HTTP 成功、协议错误与传输失败矩阵

## 安全边界

实验只使用仓库的回环服务器和虚构设备 `PUMP-01`。不要填入真实域名、Cookie、Authorization、Token、人员信息或生产工单；不要把 `-v` 输出连同凭据粘进公开记录；不要禁用 TLS 校验来测试真实站点。

## 一、先预测

在 `worksheet.md` 写出六个场景的 method、预期 status、响应 `Content-Type`、body 解释方式、curl 退出码和 stderr。特别预测：默认 curl 收到 404/503 后，退出码是否必然非零？超时有没有 HTTP status？

## 二、自动重放

执行：

```bash
ruby run_lab.rb
```

预期最后一行是 `http-curl verification: PASS`。脚本会在系统临时目录保存本次 header/body，断言后自动清理，不会污染仓库。

## 三、手动拆分报文

在示例目录运行 `ruby server.rb`，另开终端逐条执行并记录：

```bash
evidence_dir="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-http.XXXXXX")"
curl --noproxy "*" --silent --show-error \
  --dump-header "$evidence_dir/get.headers" \
  --output "$evidence_dir/get.body" \
  --write-out 'status=%{http_code} type=%{content_type} total=%{time_total}\n' \
  http://127.0.0.1:45678/api/work-orders/FC-1001

curl --noproxy "*" --silent --show-error \
  --request POST \
  --header 'Content-Type: application/json' \
  --data-binary '{"deviceId":"PUMP-01"}' \
  --dump-header "$evidence_dir/post.headers" \
  --output "$evidence_dir/post.body" \
  --write-out 'status=%{http_code} type=%{content_type}\n' \
  http://127.0.0.1:45678/api/work-orders
```

只查看 `evidence_dir` 指向且不含凭据的文件。练习结束删除自己刚创建的该目录；不要对不明确的 `/tmp` 路径做通配删除。

## 四、注入三类故障

1. 请求 `/missing`，观察 404 与 `application/problem+json`；
2. 向 POST 端点发送 `Content-Type: text/plain`，观察 415 与文本 body；
3. 请求 `/slow` 并加 `--max-time 0.10`，记录退出码 28、status `000` 与 stderr。

每个场景都写“收到 HTTP 响应”或“未收到完整 HTTP 响应”。不要把 status `000` 当成服务器返回的 HTTP 状态码；它只是 curl 的占位输出。

## 验收

- 200/201、404/415、503 依据 status 分类，而不是只看 body 文案；
- 请求和响应的 `Content-Type` 分开记录；
- JSON 与非 JSON body 不混读；
- 404/503 的 HTTP 语义与 curl 传输退出码分开；
- 超时能由最大时限、退出码 28、status `000` 和 stderr 重放；
- 所有测试均局限回环地址，记录中没有真实凭据。

未验证：HTTP/2、HTTP/3、真实 TLS、代理、重定向、认证、浏览器 CORS 和生产服务均不在本实验范围。
