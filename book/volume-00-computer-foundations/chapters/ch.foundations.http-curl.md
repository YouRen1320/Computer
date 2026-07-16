---
schema_version: 2
edition: 2026.2-draft
id: ch.foundations.http-curl
title: HTTP 报文、方法、状态码、Header、Body 与 curl
responsibility: 教授 HTTP 请求响应契约和 curl 取证，不提前引入具体后端或浏览器框架
volume: '00'
order: 10
level: L1
status: drafting
path: book/volume-00-computer-foundations/chapters/ch.foundations.http-curl.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.network-layers
version_surfaces: []
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释HTTP 报文、方法、状态码、Header、Body 与 curl的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - http-message
  - http-curl
  covers_topics:
  - http.request-response
  - http.method-status
  - http.header-body
  - http.curl-request
  - http.content-type
  - http.timeout-evidence
  uses_capabilities:
  - foundation.network-transport
  - foundation.shell-command-stream
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用 curl 保存 GET/POST 请求的 method、status、headers、body、Content-Type 和计时信息，形成成功/客户端错/服务端错矩阵
  covers_topic_groups:
  - http-message
  - http-curl
  covers_topics:
  - http.request-response
  - http.method-status
  - http.header-body
  - http.curl-request
  - http.content-type
  - http.timeout-evidence
  uses_capabilities:
  - foundation.network-transport
  - foundation.shell-command-stream
  - foundation.http-message
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入错误 Content-Type、404 与连接超时，区分 HTTP 错误响应和没有收到 HTTP 响应的传输失败
  covers_topic_groups:
  - http-message
  - http-curl
  covers_topics:
  - http.request-response
  - http.method-status
  - http.header-body
  - http.curl-request
  - http.content-type
  - http.timeout-evidence
  uses_capabilities:
  - foundation.network-transport
  - foundation.shell-command-stream
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# HTTP 报文、方法、状态码、Header、Body 与 curl

上一章走到 TLS 为止：名称已经解析，TCP 已连接，必要时加密通道也已建立。但“通道能用”不等于“请求正确”，更不等于“业务成功”。HTTP 解决的是另一组问题：客户端想对哪个目标做什么，携带哪些元数据与内容；服务器如何用状态码、响应字段和内容表达处理结果。

本章不依赖 Spring、浏览器、Vue 或具体后端框架。我们直接阅读 HTTP 请求与响应，用 curl 把 Header、Body、状态码、耗时、stderr 和进程退出码分开保存。这样，看到“失败”时可以回答两个独立问题：是否收到了 HTTP 响应？若收到了，响应表达的是成功、客户端错误还是服务端错误？

## 本章要解决的问题

完成本章后，你应当能够：

1. 把 HTTP 交互分成请求和响应，指出每方的责任；
2. 在 HTTP/1.1 文本示例中识别请求行/状态行、Header、空行和 Body；
3. 解释方法表达请求意图，状态码表达响应结果类别；
4. 用 2xx、4xx、5xx 对结果分类，同时知道 1xx 与 3xx 的存在；
5. 区分请求 `Content-Type` 与响应 `Content-Type`；
6. 不因 Body 看起来像 JSON 就无条件按 JSON 解析；
7. 用 curl 分开保存响应 Header 与 Body，并输出 status、媒体类型和耗时；
8. 区分 HTTP 错误响应与 DNS/TCP/TLS/超时等“没有收到响应”的传输失败；
9. 解释为什么默认 curl 完整收到 404 或 503 时，进程退出码仍可能为 0；
10. 为 FactoryCare 建立 2xx、4xx、5xx 与传输失败的取证矩阵；
11. 在记录中保护 Authorization、Cookie、内部地址与人员/设备信息。

本章的达标证据不是“会敲一条 curl”，而是能先预测 status、媒体类型和退出码，再运行、注入故障、只改一个条件并复跑。

## 前置：先守住网络层边界

请先完成 [IP、DNS、端口、TCP 与 TLS 分层](./ch.foundations.network-layers.md)。HTTP 请求要通过某种下层传输送达。若 DNS 失败、TCP 被拒绝或 TLS 校验失败，客户端通常没有收到 HTTP 状态行，因此不能编造 404、500 或任何其他 HTTP 结果。

本章采用以下状态区分：

- **received response**：收到并解析了 HTTP 响应状态；
- **HTTP error response**：收到了 4xx 或 5xx，说明 HTTP 交换发生了；
- **transport failure**：没有得到可用 HTTP 状态，错误发生在名称、连接、TLS、超时或本地客户端；
- **not evaluated**：证据不足，不猜测。

## 请求与响应：一问一答的协议模型

HTTP 客户端构造请求，服务器接收后产生一个或多个响应；日常最终结果通常关注最终响应。请求至少表达方法和目标，可能还有 Header 与 Body。响应至少表达状态码，可能还有 Header 与 Body。

抽象模型如下：

```text
客户端
  ── Request: method + target + headers + optional body ──▶
服务器
  ◀─ Response: status + headers + optional body ─────────
客户端
```

“请求”与“响应”必须分栏记录。请求的 `Content-Type` 描述请求内容；响应的 `Content-Type` 描述响应内容。两者可以不同。例如客户端发送 JSON，服务端可能返回纯文本错误；若日志只有一栏 `contentType`，就容易把两侧混淆。

### HTTP 语义与线上编码

HTTP 的方法、状态码与字段语义可跨不同协议版本保留，但线上编码方式不同。HTTP/1.1 常可用文本形式展示起始行与字段；HTTP/2 和 HTTP/3 使用不同的二进制帧与传输机制，不能把 HTTP/1.1 的逐行格式硬套到它们的线上字节。

本章本地服务器故意使用 HTTP/1.1，便于零基础读者直接观察。我们学习的是请求/响应语义与取证边界，不宣称已经验证 HTTP/2、HTTP/3、代理或浏览器行为。

## HTTP/1.1 报文的可读骨架

一个简化请求：

```http
POST /api/work-orders HTTP/1.1
Host: 127.0.0.1:45678
Content-Type: application/json
Content-Length: 22

{"deviceId":"PUMP-01"}
```

可拆成：

1. **请求行**：方法 `POST`、请求目标 `/api/work-orders`、协议版本；
2. **请求 Header**：`Host`、`Content-Type`、`Content-Length`；
3. **空行**：标记字段区结束；
4. **请求 Body**：这里是 JSON 字节。

对应响应可能是：

```http
HTTP/1.1 201 Created
Content-Type: application/json
Content-Length: 62
Location: /api/work-orders/FC-2001

{"id":"FC-2001","deviceId":"PUMP-01","status":"REPORTED"}
```

响应拆成：

1. **状态行**：协议版本、状态码 `201`、便于人读的原因短语；
2. **响应 Header**：媒体类型、长度与新资源位置等元数据；
3. **空行**；
4. **响应 Body**：新建结果的表示。

不要用原因短语代替状态码进行程序判断。稳定的机器判断以三位数字状态码为核心；短语可能缺失、不同语言或被实现调整。

## 方法：客户端想做什么

HTTP 方法是请求语义的一部分。常见方法可先建立以下直觉：

| 方法 | 常见意图 | Body 情况 | 本章关注点 |
| --- | --- | --- | --- |
| GET | 获取目标当前表示 | 通常不依赖请求 Body | 不要用 GET 暗藏修改动作 |
| POST | 把内容交给目标处理，常用于创建或动作 | 常有 | 明确请求媒体类型 |
| PUT | 用给定表示创建或替换目标状态 | 常有 | 目标与完整表示由契约决定 |
| PATCH | 对目标做部分修改 | 常有 | 补丁格式必须明确 |
| DELETE | 请求移除目标关联 | 通常较少依赖 Body | 最终结果仍看响应 |
| HEAD | 获取与 GET 类似的响应元数据而不传响应内容 | 通常无 | 不能当作完整 GET Body |
| OPTIONS | 查询目标的通信选项 | 依契约 | 不等于业务权限证明 |

这张表描述常见协议意图，不替具体 API 设计契约。方法名本身不能证明业务已经完成。发送 `POST` 不会自动创建工单；服务器可能返回 400、401、403、409、415、500，也可能在传输层就失败。必须结合状态码和响应证据。

### 方法与 shell 命令

用 curl 显式指定 GET：

```bash
curl --request GET http://127.0.0.1:45678/api/work-orders/FC-1001
```

发送 JSON POST：

```bash
curl --request POST \
  --header 'Content-Type: application/json' \
  --data-binary '{"deviceId":"PUMP-01"}' \
  http://127.0.0.1:45678/api/work-orders
```

单引号由 shell 负责保护 JSON 中的双引号。在不同 shell，尤其 Windows 命令环境中，引用规则不同；不要把某个平台的引号写法当成 HTTP 规则。HTTP 最终看到的是传出的字节，不理解 shell 引号。

### `--data-binary` 的教学选择

curl 有多种发送数据的选项，它们可能对换行、文件读取或默认方法有不同处理。本章使用 `--data-binary` 是为了让示例 Body 尽量按给定字节发送，并显式写出 `--request POST`，让方法与 Body 两项证据都清楚。真实项目应继续查阅当期官方手册，不靠记忆混用选项。

## 状态码：服务器怎样表达结果类别

HTTP 状态码为三位数字，第一位形成类别：

| 类别 | 含义 | 初学判断 |
| --- | --- | --- |
| 1xx | 信息性响应 | 交互仍可能继续，不作为常见最终业务结果 |
| 2xx | 成功 | 请求已被成功接收、理解和接受，具体完成程度看该状态语义 |
| 3xx | 重定向 | 需要位置选择、缓存验证或其他后续处理 |
| 4xx | 客户端错误 | 请求有语法、认证、权限、目标或契约方面的问题 |
| 5xx | 服务端错误 | 服务器未能完成一个表面上可处理的请求 |

类别只给第一层分类，具体码还有更精确语义。`200 OK`、`201 Created`、`204 No Content` 都是 2xx，但 Body 与资源结果不同；`400 Bad Request`、`404 Not Found`、`415 Unsupported Media Type` 都是 4xx，却指向不同修复方向；`500` 与 `503` 也不应完全等同。

### 2xx 不都带 JSON Body

`204 No Content` 的成功语义本来就不包含响应内容。客户端若把所有 2xx 都强制 `JSON.parse`，会把合法空 Body 当成故障。判断顺序应结合具体状态码、方法和契约。

### 4xx 不等于“网络没通”

收到 404 或 415 已证明服务器或中间 HTTP 节点产生了响应。网络链至少走到了 HTTP。此时应核对 target、method、请求字段和 Body，而不是先改 DNS。

### 5xx 也需要保留 Body 和 Header

5xx 表示服务端错误类，但响应可能带错误 ID、重试建议或文本说明。不能只截状态码，也不能因为 curl 默认退出 0 就忽略它。自动化要明确自己的 HTTP 判定策略。

### 状态码不能单独证明业务最终状态

状态码描述这次响应语义。某些异步操作、代理链路或后续处理还有额外边界；即使收到成功，也要按 API 契约判断最终业务状态。本章不提前教授资源版本、幂等或异步任务设计，只要求不把状态类别过度外推。

## Header：报文的结构化元数据

HTTP 字段由名称和值构成。字段名称在协议语义上不区分大小写，但日志和应用代码应采用一致写法以便阅读。字段值的语法由具体字段定义，不能把所有值都用逗号随意拆分。

常见入门字段：

- `Host`：HTTP/1.1 请求目标主机信息的一部分；
- `Content-Type`：当前报文内容的媒体类型；
- `Content-Length`：内容长度，单位是字节，不是“字符数”；
- `Accept`：客户端偏好的响应媒体类型，不等同于请求 `Content-Type`；
- `Location`：在特定响应中提供位置；
- `Authorization`：认证凭据，记录和分享时必须保护；
- `Cookie` / `Set-Cookie`：状态信息，通常含敏感内容；
- `Cache-Control`：缓存相关指令，本章示例使用 `no-store` 保持观察简单。

Header 不是“无关紧要的前缀”。媒体类型、长度、认证和缓存行为都可能改变客户端如何解释 Body。

## Body：报文携带的内容字节

Body 是零个或多个字节。它可能是 JSON、文本、图片、压缩内容或其他格式，也可能不存在。屏幕上看见的字符只是客户端按某种媒体类型和字符编码解释字节后的结果。

三条规则：

1. 不用文件扩展名或首字符猜 Body 类型；
2. 先看响应状态与 `Content-Type`，再选择解析器；
3. 解析成功不等于业务契约正确，还要校验字段、类型与含义。

### Header 与 Body 的空行边界

HTTP/1.1 文本报文中，空行结束 Header 区。若手写原始报文时漏掉空行，接收方可能继续等待字段结束或判为格式错误。日常使用 curl 时由工具生成报文边界，不建议零基础读者手拼 TCP 字节。

### `Content-Length` 是字节数

中文字符在 UTF-8 中常占多个字节。若服务端按字符数填写 `Content-Length`，客户端可能提前截断或继续等待。配套本地服务器使用 `body.bytesize`，强调线上长度的单位。

## Content-Type：请求与响应要分开看

### 请求 Content-Type

当请求包含 Body，`Content-Type` 告诉服务器这些字节采用什么媒体类型。例如：

```http
Content-Type: application/json
```

只把 JSON 字符串放进 Body，而不声明媒体类型，服务器可以拒绝。配套端点明确要求 `application/json`，错误发送 `text/plain` 时返回 415。

### 响应 Content-Type

响应字段告诉客户端如何解释响应 Body。成功响应可能是 `application/json`；错误响应可能是 `application/problem+json` 或 `text/plain`。客户端不能因为“这个 API 平常返回 JSON”就对所有错误 Body 强制 JSON 解析。

### 参数与基础媒体类型

`text/plain; charset=utf-8` 包含媒体类型与字符集参数。入门判断时可以先取分号前的基础媒体类型，再根据该媒体类型的规范处理参数。不要用简单的整串相等判断，把媒体类型允许的合法参数误判掉。本章 JSON 端点使用不带参数的 `application/json`。

### `application/problem+json`

带 `+json` 后缀的媒体类型使用 JSON 结构语法，但其业务字段由该媒体类型/接口契约决定。它可以按 JSON 语法解析，却不能当成成功工单对象。语法与业务模型是两个层次。

### `Accept` 不等于 `Content-Type`

请求 `Content-Type` 说明“我发送的 Body 是什么”；`Accept` 表达“我愿意接收什么”。把 `Accept: application/json` 写上，并不能替代请求 JSON 的 `Content-Type`。服务端仍可能根据契约返回其他类型或错误。

## curl：协议取证工具，而不是业务真相机器

curl 可以构造请求、显示或保存响应，并用退出码报告客户端/传输执行结果。它不会自动知道你的业务成功标准。必须同时读取 HTTP status 与 curl exit。

### 最小 GET

```bash
curl http://127.0.0.1:45678/api/work-orders/FC-1001
```

这会把响应 Body 默认写到 stdout，但不便于把 Header、状态码与 Body 分离。学习取证应使用更完整命令。

### 分开 Header、Body 与摘要

```bash
evidence_dir="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-http.XXXXXX")"
curl --noproxy "*" \
  --silent --show-error \
  --dump-header "$evidence_dir/response.headers" \
  --output "$evidence_dir/response.body" \
  --write-out 'status=%{http_code} type=%{content_type} total=%{time_total}\n' \
  http://127.0.0.1:45678/api/work-orders/FC-1001
```

各参数职责：

- `--noproxy "*"`：本章仅用于确保回环实验不经过用户代理；不要照搬成生产网络策略；
- `--silent`：隐藏进度条；
- `--show-error`：与 silent 配合，仍把错误写到 stderr；
- `--dump-header`：把响应 Header 保存到独立文件；
- `--output`：把 Body 保存到独立文件；
- `--write-out`：在传输结束后输出 curl 观测值；
- `%{http_code}`：最终 HTTP 状态；没有收到状态时常显示 `000` 占位；
- `%{content_type}`：curl 从响应中得到的内容类型；
- `%{time_total}`：本次总耗时。

`mktemp -d` 为本次实验创建独立临时目录，避免覆盖固定文件名。临时文件名不能含真实工单号或人员信息；确认文件中无凭据后再分享，用完删除自己记录的该临时目录。

### `-i` 与 `-v` 的边界

`-i/--include` 会把响应 Header 与 Body 一起输出，临时观察方便，但自动解析时容易混在一起。`-v/--verbose` 提供更详细的连接和报文信息，可能暴露 Authorization、Cookie、内部名称和代理信息。生产取证要最小化输出并脱敏；不要把完整详细日志直接贴到公开 issue。

### 默认 curl exit 与 HTTP status 是两套信号

curl 的默认目标是完成传输。服务器完整返回 404 或 503 时，HTTP 语义是错误响应，但传输本身可能成功，因此 curl 进程退出码可以为 0。

这不是 curl 忽略错误，而是两种问题不同：

- `curl_exit`：客户端是否按工具规则完成传输；
- `http_status`：服务器响应表达什么结果。

自动化若只写 `if curl_success then business_success`，会把 404/503 误判为成功。

### `--fail` 与 `--fail-with-body`

curl 官方手册说明，`--fail` 可让 HTTP 400 及以上返回错误退出，同时不输出响应 Body；`--fail-with-body` 则在返回错误退出的同时保留 Body。选哪一个是自动化契约决策，不是协议本身。调试通常需要保留错误 Body，但仍要注意其中可能有敏感信息。

即使使用这些选项，也建议保存实际 HTTP status；退出码 22 只能说明启用失败策略后遇到 HTTP 错误类，具体是 404、415 还是 503 仍需状态码。

### 超时参数与退出码

`--max-time` 给整个 curl 操作设置最大时限。配套实验请求慢端点时使用：

```bash
curl --silent --show-error \
  --max-time 0.10 \
  --write-out 'status=%{http_code}\n' \
  http://127.0.0.1:45678/slow
```

预期 curl 退出码为 28，stderr 非空，`http_code` 为 `000`。这里 `000` 不是服务器发送的 HTTP 状态码；它表示 curl 没有可报告的 HTTP 状态。准确结论是“在 0.10 秒总预算内未收到响应状态”，不是“服务器返回 000”。

真实诊断还可区分连接超时与总超时。本章先要求记录使用了哪个预算、是否收到状态行和退出码；不要在无证据时把总超时写成 TCP connect timeout。

### 保存退出码

命令执行后立即读取 shell 的上一命令退出状态；不要在中间插入别的命令，否则取到的是后者结果。配套自动验证器直接由进程 API 捕获 exit，避免手工覆盖。

## 可重复的本地服务

示例目录提供只绑定 `127.0.0.1` 的固定教学服务：

| method/target | status | 响应类型 | 用途 |
| --- | ---: | --- | --- |
| GET `/api/work-orders/FC-1001` | 200 | application/json | 查询成功 |
| POST `/api/work-orders` + 正确 JSON | 201 | application/json | 创建成功 |
| GET `/missing` | 404 | application/problem+json | 目标不存在 |
| GET `/explode` | 503 | text/plain | 服务端错误类 |
| POST + `Content-Type: text/plain` | 415 | text/plain | 请求媒体类型错误 |
| GET `/slow` | 最终可 200，但客户端先超时 | application/json | 无 HTTP 状态的超时证据 |

一键运行：

```bash
cd examples/encyclopedia/ch.foundations.http-curl
ruby verify.rb
```

预期摘要：

```text
2xx: GET=200 JSON; POST=201 JSON with Location
4xx: 404 problem+json and 415 text/plain classified by HTTP status
5xx: 503 text/plain received; default curl transfer exit remained 0
media type: JSON parsed only for application/json or application/problem+json
transport failure: /slow curl_exit=28 http_status=000 stderr=present
http-curl verification: PASS
```

验证器在系统临时目录保存每次 Header 与 Body，断言后清理。它只用虚构设备 ID，不读取环境 Token，不访问公网。

## 六个场景怎样判断

### 200 查询成功

证据至少包括：curl exit 0、status 200、响应 `Content-Type` 为 JSON 类型、Body 能按 JSON 解析且包含预期字段。不要只看 Body 里有 `status` 字符串；HTTP status 和工单业务 status 是两个字段。

### 201 创建成功

status 201 表达创建结果；示例还返回 `Location`。客户端应记录响应状态和位置，不应假设所有 POST 成功都是 200。

### 404 目标不存在

已经收到 HTTP 响应。默认 curl exit 0 并不改变 404 的客户端错误类别。响应媒体类型为 `application/problem+json`，可以按 JSON 语法解析错误详情，但不能当作工单成功对象。

### 503 服务不可用

已经收到 HTTP 5xx。示例 Body 为 `text/plain`。若代码无条件 JSON.parse，它会制造第二个客户端解析错误，掩盖原始 503。应保留原始文本。

### 415 请求媒体类型不支持

服务端读到了 POST，却发现请求 `Content-Type` 不是 `application/json`。只修复请求 Header 后重放同一 Body，可以验证单变量修复。不要同时改 URL、方法和 JSON 字段。

### 超时

客户端在预算内没有收到 HTTP 状态，curl exit 28、stderr 有超时信息、status 占位 `000`。这属于传输/等待失败，不能归为 4xx 或 5xx，也不能解析一个不存在的响应 Body。

## 调试决策树

遇到“API 调用失败”，先回答是否收到 HTTP status：

```text
有没有收到合法 HTTP status？
├─ 没有
│  ├─ 看 curl exit 与 stderr
│  ├─ 按 DNS/TCP/TLS/timeout 阶段定位
│  └─ 不编造 HTTP 4xx/5xx
└─ 有
   ├─ 先按 status 分类 2xx/3xx/4xx/5xx
   ├─ 再看响应 Content-Type
   ├─ 按媒体类型读取 Body
   └─ 对照 method、target、请求 Content-Type 与业务契约
```

### 第一步：冻结请求

记录 method、脱敏 target、请求 Header 名单、请求媒体类型、Body 大小/脱敏摘要、超时预算和执行时间。秘密字段只记录“存在/已脱敏”，不保存值。

### 第二步：分离四路输出

至少分开响应 Header、响应 Body、curl write-out 和 stderr。若全混在一段文本中，状态行、错误日志与 JSON 容易互相污染。

### 第三步：先传输，后 HTTP

若没有 HTTP 状态，回到网络分层。若有状态，才按类别判断。不要因 curl exit 0 跳过 status，也不要因 exit 非零就猜 status。

### 第四步：按媒体类型读 Body

JSON 类型使用 JSON 解析器；文本保留原文；二进制以安全方式保存而非打印终端。解析失败要保留原始字节与响应类型，不能用空对象覆盖。

### 第五步：单变量修复

- 404：只修 target；
- 415：只修请求 `Content-Type`；
- timeout：先确认阶段与预算，再根据可重复证据调整服务或合理预算；
- 503：服务端错误，不通过篡改请求让错误“消失”。

修复后运行同一取证命令，比较 status、type、exit 和耗时。

## 常见错误与失败原因

### 只看 Body 文案

成功和错误都可能返回 JSON；代理还可能返回 HTML 或纯文本。Body 中写“success”不替代 status，Body 中写“error”也不能告诉你是否收到 HTTP 响应。先看状态与媒体类型。

### 只看 curl exit

默认 curl 完整收到 404/503 时 exit 可为 0。只看 exit 会把 HTTP 错误算作成功。反过来，超时 exit 28 时没有 5xx 状态，不能把所有非零都归服务器错误。

### 把 `000` 当状态码

标准 HTTP 状态码是三位数字类别，但 `000` 不是服务器响应状态。它是 curl 在没有可报告 HTTP code 时的输出值。应结合 exit 与 stderr 解释。

### 请求与响应 Content-Type 混为一谈

请求发送 JSON、响应返回文本完全可能。分别命名 `request_content_type` 与 `response_content_type`，不要共用一个模糊字段。

### 看到 `{` 就 JSON.parse

类型判断不应只靠外观。文本可以恰好以 `{` 开头，JSON 类型也可能包含非法字节。先依据响应媒体类型，再捕获解析失败，保留原始证据。

### 用 `Accept` 代替请求 `Content-Type`

`Accept` 表达响应偏好，不能说明请求 Body 的格式。发送 JSON 仍应按契约声明请求 `Content-Type`。

### 忘记 shell 引用

未正确引用的 `&`、空格、`?`、`$`、引号可能先被 shell 解释，curl 根本没有收到你以为的参数。诊断时区分 shell 层与 HTTP 层。不要为了省事把含 Token 的完整命令写进 shell 历史。

### 无界等待

没有超时的自动化可能永久占用任务；预算过短又会制造假失败。设置与场景相符的有限预算，并记录是哪一种超时。示例的 0.10 秒只用于本机确定性故障注入，不能直接抄成生产 SLA。

### 盲目跟随重定向

curl 可以跟随重定向，但这会产生后续请求，可能改变方法、目标与凭据边界。初学取证先观察原始 3xx 和 `Location`，再明确决定是否跟随。不要在不知目标的情况下把敏感 Header 发送到新主机。

### 把详细跟踪公开

verbose 输出可能带 Authorization、Cookie、代理、证书和内部地址。分享前删除秘密值；若秘密已经暴露，应按真实泄露流程轮换，而不是只删日志。

## 安全与隐私

curl 可以发送任意 Header 与 Body，因此也很容易把真实秘密留在终端历史、进程列表、临时文件或聊天记录中。

安全规则：

- 教材命令只用虚构 ID，不需要 Authorization；
- 不在命令行硬编码真实 Token；
- 不把 Cookie、签名、个人信息和设备敏感数据写入公共 issue；
- 临时 Header/Body 文件采用受控路径，用完确认并清理；
- 不向不属于你的服务进行写操作或压力测试；
- 不使用 `--insecure` 掩盖真实 TLS 故障；
- 不因调试而关闭代理、证书或防火墙策略；
- 对 Body 大小设置合理边界，避免把未知二进制直接输出终端。

配套服务器只监听回环，固定返回教学数据，并设置 `Cache-Control: no-store`。它不是生产服务器示例，不实现认证、并发治理或完整 HTTP 解析。

## FactoryCare 场景：从“红色报错”到证据矩阵

FactoryCare 的维修端要创建工单。一个完整取证记录可以包含：

```text
request_method=POST
request_target=/api/work-orders
request_content_type=application/json
request_body=deviceId present; value redacted/demo-only
curl_exit=0
http_status=415
response_content_type=text/plain; charset=utf-8
response_body_summary=expected application/json
transport=completed
classification=client_contract_error
```

这里“client”指 HTTP 4xx 类别，不等于责怪最终用户。错误可能来自前端代码、网关转换、文档不一致或服务端契约部署。分类用于确定下一步证据，不是组织归责。

### 2xx：仍要验证具体契约

查询返回 200 时，检查响应媒体类型与必要字段；创建返回 201 时，检查新资源标识/位置。不能只因 status 属于 2xx 就把任意 Body 强制转成目标对象。

### 4xx：优先核对请求合同

404 检查 method 与 target；415 检查请求 `Content-Type` 与实际字节；其他 4xx 还可能涉及校验、认证或权限。敏感字段保持脱敏。

### 5xx：保留关联信息，不制造第二故障

503 的文本 Body 应原样保留摘要；不要强制解析 JSON后只上报“Unexpected token”。同时记录时间、目标和可能的错误关联 ID，为服务端日志检索提供线索。

### 无 HTTP 状态：回到底层

若 status `000` 且 exit 28，记录超时预算；若是名称或 TLS 退出错误，则回到上一章分层。此时说“后端返回 500”是无证据推断。

### 一个可操作故障摘要

```text
已确认：POST 已通过 HTTP 到达回环教学服务并收到 415；curl 传输退出 0。
首个协议失败：请求声明 text/plain，端点要求 application/json。
响应：text/plain，Body 保留为文本，未尝试 JSON 解析。
未确认：修正媒体类型后的字段校验与业务创建结果。
下一步：只把请求 Content-Type 改为 application/json，保持 target 与 Body 不变后复跑。
```

这比“接口报错，请后端看看”更容易复现，也没有越过证据边界。

## 独立实验闭环

使用 `labs/encyclopedia/ch.foundations.http-curl/`：

1. 先预测六个场景的 method、status、媒体类型、curl exit 与 stderr；
2. 运行自动验证，确认 2xx/4xx/5xx 和 timeout 断言；
3. 手动启动本地服务器，用 curl 分开保存 Header 与 Body；
4. 注入 404、错误请求 Content-Type 与超时；
5. 每次写清是否收到 HTTP 响应；
6. 只改变一个条件复跑；
7. 画出“传输判定”和“HTTP 判定”两条轴；
8. 用 120 秒解释为什么 404 可以对应 curl exit 0。

自动 PASS 只证明固定脚本预言。你的预测表、命令解释、隐私处理和复述仍需单独检查。

## 速查表

### 报文部件

| 部件 | 请求 | 响应 | 关键边界 |
| --- | --- | --- | --- |
| 起始信息 | method + target | status code | 不用原因短语做机器判断 |
| Header | 请求元数据 | 响应元数据 | 两侧同名字段也属于不同报文 |
| Body | 可选请求内容 | 可选响应内容 | 可能为空或非 JSON |
| Content-Type | 请求 Body 类型 | 响应 Body 类型 | 必须分栏 |

### curl 取证

| 需要的证据 | 常用方式 | 不能单独推出 |
| --- | --- | --- |
| 响应 Header | `--dump-header` | Body 一定可解析 |
| 响应 Body | `--output` | HTTP 成功 |
| HTTP status | `%{http_code}` | curl 传输退出状态 |
| 响应媒体类型 | `%{content_type}` | 业务字段有效 |
| 总耗时 | `%{time_total}` | 慢在哪一阶段 |
| stderr | `--show-error` | 服务器一定收到了请求 |
| curl exit | shell/进程状态 | HTTP status 类别 |

### 判断矩阵

| curl exit | HTTP status | 解释起点 |
| ---: | --- | --- |
| 0 | 2xx | 传输完成且 HTTP 成功类，继续验契约 |
| 0 | 4xx | 传输完成，客户端错误响应 |
| 0 | 5xx | 传输完成，服务端错误响应 |
| 28 | `000`/无 | 超时，未得到 HTTP 状态 |
| 非零 | 可能无 | 查 curl 错误类别与 stderr，不猜 4xx/5xx |

具体退出码受执行条件与选项影响；脚本应记录而不是凭印象推断。

## 复述题

1. HTTP 请求与响应各由哪些基本部分组成？
2. HTTP/1.1 的空行有什么作用？
3. 方法表达什么？为什么 POST 不自动证明创建成功？
4. 2xx、4xx、5xx 各是什么类别？
5. 为什么 204 不能被无条件 JSON.parse？
6. 请求和响应 `Content-Type` 有什么区别？
7. `Accept` 为什么不能替代请求 `Content-Type`？
8. Body 看起来像 JSON 时，为什么仍要看媒体类型？
9. 默认 curl 完整收到 404 时，退出码为何可能为 0？
10. `--fail-with-body` 改变的是 HTTP 协议还是 curl 的退出策略？
11. status `000` 为什么不是服务器状态码？
12. 超时证据至少需要哪些字段？
13. 如何把 Header、Body、write-out 与 stderr 分开？
14. verbose 日志可能泄露什么？
15. FactoryCare 创建失败时，怎样区分 415、503 与超时？

## 间隔复习与闭环

- **现在**：不运行命令，预测 200、404、503、415、timeout 的 status/exit/type；
- **1 天后**：120 秒复述请求、响应、方法、状态、Header 与 Body；
- **3 天后**：从空白写一条分离 Header/Body/status/type/time 的 curl 命令；
- **7 天后**：重跑故障矩阵，只改请求 Content-Type 修复 415；
- **14 天后**：拿一条脱敏 API 错误，先判断“是否收到 HTTP 响应”，再写最小故障摘要。

如果你仍把 `curl exit 0` 等同业务成功，或把 status `000` 当服务器状态，请返回实验重新预测，而不是继续学习框架封装。

## 官方一手资料与复核边界

以下资料于 **2026-07-16** 从官方来源复核。涉及 curl 当前选项行为的陈述只依据 curl 官方手册；HTTP 语义只依据 IETF/RFC Editor 规范：

- [RFC 9110：HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)：方法、字段、内容、媒体类型、状态码与 2xx/4xx/5xx 类别；
- [RFC 9112：HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112.html)：HTTP/1.1 报文语法、起始行、字段与消息边界；
- [curl 官方命令行手册](https://curl.se/docs/manpage.html)：`--dump-header`、`--output`、`--write-out`、`--max-time`、`--fail`、`--fail-with-body` 与退出码说明。

本地自动验证观察到的是当前 macOS 环境中的 curl 8.7.1 与 Ruby/LibreSSL 组合；这只是本次平台证据，不把版本写入章节规范面，也不声称 Windows、Linux、HTTP/2、HTTP/3、真实 TLS、代理或浏览器已经验证。人工零基础试读、跨平台复测和全书一致性审查仍延期到集中审查阶段。
