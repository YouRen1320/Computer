# Spring Boot：REST、DTO、校验与错误处理

## 1. Web API 是一份跨程序的约定

前端、移动端或另一个服务无法直接调用 Java 对象的方法。它们通过网络发送 HTTP 请求，后端再返回 HTTP 响应。

因此 API 不只是一个 Controller 方法。它是客户端与服务端共同依赖的契约，至少包括：

- 请求方法和 URL；
- path、query、header 和 body 中分别有什么；
- 请求和响应的数据格式；
- 成功和各类失败的状态码；
- 字段的含义、是否必填以及兼容规则；
- 分页、缓存、重试和幂等语义。

一个 API 即使“能返回 JSON”，如果错误时状态码、字段名和结构每次都变，仍然不是稳定的契约。

## 2. 一个 HTTP 交互里有什么

请求可以简化为：

```http
POST /api/work-orders HTTP/1.1
Host: factorycare.example
Content-Type: application/json
Accept: application/json

{
  "deviceId": "DEV-1001",
  "description": "motor overheated"
}
```

响应可以简化为：

```http
HTTP/1.1 201 Created
Content-Type: application/json
Location: /api/work-orders/WO-9001

{
  "id": "WO-9001",
  "status": "OPEN"
}
```

里面的主要部分是：

- **method**：客户端想做什么；
- **target/URL**：想操作哪个资源；
- **headers**：传递媒体类型、认证、缓存等元信息；
- **body**：本次请求或响应的主要数据；
- **status code**：服务端对结果类别的标准表达。

`curl` 的价值是让你绕开前端页面，直接看真实 HTTP 输入和输出：

```bash
curl -i \
  -X POST http://localhost:8080/api/work-orders \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"deviceId":"DEV-1001","description":"motor overheated"}'
```

`-i` 让响应头也被显示。调试 API 时只看 body，容易漏掉状态码、`Content-Type`、重定向和缓存信息。

## 3. 把 API 设计成对资源的操作

REST 风格中，URL 通常表达资源，HTTP 方法表达操作语义：

| 意图 | 示例 | 常用方法 |
| --- | --- | --- |
| 查看工单列表 | `/api/work-orders` | `GET` |
| 查看一张工单 | `/api/work-orders/{id}` | `GET` |
| 创建工单 | `/api/work-orders` | `POST` |
| 整体替换资源 | `/api/work-orders/{id}` | `PUT` |
| 部分修改资源 | `/api/work-orders/{id}` | `PATCH` |
| 删除资源 | `/api/work-orders/{id}` | `DELETE` |

`POST /createWorkOrder` 并非永远错误，但如果 API 到处把动词、资源名和内部方法名拼进 URL，客户端很难推断统一规则。

有些业务动作不是简单 CRUD，例如“指派工单”。可以把它建模成状态修改、子资源或命令端点。最重要的不是追求唯一 URL 写法，而是让意图、输入、结果和幂等性稳定可说明。

## 4. HTTP 方法的安全性和幂等性

两个概念很容易混淆：

- **安全（safe）**：请求语义上不应修改服务器资源；
- **幂等（idempotent）**：相同请求执行一次或多次，服务器目标状态效果相同。

`GET` 在语义上既安全又幂等。`DELETE /work-orders/42` 不是安全操作，但“删除后资源不存在”这个目标状态可以是幂等的。

`POST` 通常不天然幂等。客户端因超时重试“创建工单”，可能创建两张。需要可安全重试时，可通过幂等键、业务唯一键和服务端记录结果来扩展契约。

这些语义是 API 协议的一部分，不是由 Controller 注解自动保证。

## 5. Spring MVC 如何找到 Controller

Spring MVC 将 HTTP 请求映射到处理方法：

```java
@RestController
@RequestMapping("/api/work-orders")
class WorkOrderController {

    @GetMapping("/{id}")
    WorkOrderResponse findById(@PathVariable String id) {
        // ...
    }
}
```

这里有三层意思：

1. `@RestController` 让类成为 Web 层 Bean，方法返回值默认用于响应 body；
2. 类级 `@RequestMapping` 定义共同路径前缀；
3. `@GetMapping` 将 GET 方法和具体路径映射到 Java 方法。

当两个处理方法同时能匹配一个请求时，会产生映射歧义。路由设计应用 method、path、媒体类型和必要条件形成清晰、不重叠的契约。

Controller 是协议适配层：它理解 HTTP，但不应包含大量业务规则。

## 6. 参数可以来自不同位置

一个请求的输入不只在 JSON body 中：

```java
@GetMapping("/{id}")
WorkOrderResponse findById(
        @PathVariable String id,
        @RequestParam(defaultValue = "false") boolean includeHistory,
        @RequestHeader("X-Tenant-Id") String tenantId
) {
    // ...
}
```

- `@PathVariable`：路径中用来确定某个资源的值；
- `@RequestParam`：查询参数，常用于过滤、排序和分页；
- `@RequestHeader`：协议元数据，如请求 ID 或条件缓存；
- `@RequestBody`：通常是一个结构化的命令或资源表示。

字符串到 `long`、枚举、日期等类型的转换，属于**参数绑定（binding）**。`abc` 无法绑定到数字 ID 时，请求应在 Web 边界以清晰的 4xx 错误结束，而不是把一个字符串传到业务深处再猜。

## 7. DTO 是 API 边界的数据形状

DTO 是 **Data Transfer Object**，可以理解为“跨边界传输时使用的数据结构”。

```java
public record CreateWorkOrderRequest(
        String deviceId,
        String description
) {}

public record WorkOrderResponse(
        String id,
        String status,
        Instant createdAt
) {}
```

请求 DTO 和响应 DTO 服务于不同方向，即使字段目前相似，也不必强行共用一个类。例如创建请求不应允许客户端伪造系统生成的 `id`、`createdAt` 和审计人。

### 7.1 为什么不直接返回领域对象

直接将领域实体序列化为 JSON 会把内部模型与外部契约绑在一起：

- 内部字段改名可能破坏客户端；
- 敏感字段可能被意外暴露；
- 懒加载或循环引用可能在序列化时引发额外查询或错误；
- 业务对象的行为和不变条件会受到 JSON 框架构造要求影响；
- 同一业务对象可能需要多种对外视图。

DTO 不是为了多写一批类，而是明确区分“内部怎样维护业务模型”和“外部可以看到什么”。

## 8. JSON 映射是一次边界转换

Spring MVC 会根据媒体类型，通过 HTTP Message Converter 将 JSON 转成 DTO，或将 DTO 转成 JSON。学习路线使用 Spring Boot 4.1 时，它的 JSON 基线是 Jackson 3；旧教程中面向 Jackson 2 的包名或配置示例不应直接照搬。

要分清几种输入：

```json
{}
```

表示字段缺失。

```json
{"description": null}
```

表示字段存在，值是 JSON `null`。

```json
{"description": ""}
```

表示值是空字符串。

```json
{"description": "   "}
```

表示值只含空白。

它们在业务上可能都是非法的，但不是同一个技术输入。JSON 映射只负责将数据转成 Java 结构；值是否符合业务要求，由后续校验和领域规则判断。

### 8.1 未知字段和兼容性

客户端发来 DTO 中没有的字段时，服务端可以选择拒绝或忽略。拒绝能更早暴露拼写错误；忽略有时更利于滚动升级。这是契约策略，应在项目中统一，不要由每个 Controller 随意决定。

## 9. Content-Type 与 Accept 回答不同问题

- `Content-Type` 说明当前这份 body 是什么格式；
- `Accept` 说明客户端希望收到什么格式。

客户端发送 JSON：

```http
Content-Type: application/json
```

客户端可接受 JSON 响应：

```http
Accept: application/json
```

请求 body 格式不被支持时，常见是 `415 Unsupported Media Type`；服务端无法提供客户端要求的响应格式时，常见是 `406 Not Acceptable`。

根据 `Accept` 等请求信息选择响应表示，叫**内容协商（content negotiation）**。即使 FactoryCare 初期只提供 JSON，理解这个区分也能快速定位“路由存在，为什么却不调用方法”。

## 10. 校验要分层

输入错误可以分为不同层次：

1. JSON 本身无法解析；
2. JSON 能解析，但不能绑定到目标类型；
3. DTO 字段违反格式、长度或必填规则；
4. 多个字段之间的组合不合法；
5. 格式全部正确，但与当前业务状态冲突。

Bean Validation 适合处理 DTO 结构层面的规则：

```java
public record CreateWorkOrderRequest(
        @NotBlank String deviceId,
        @NotBlank @Size(max = 500) String description
) {}
```

Controller 参数需要触发校验：

```java
@PostMapping
ResponseEntity<WorkOrderResponse> create(
        @Valid @RequestBody CreateWorkOrderRequest request
) {
    // ...
}
```

只在 DTO 上写注解，但边界没有触发校验，规则不会凭空执行。

### 10.1 字段规则和跨字段规则

`@NotBlank`、`@Size` 这类规则只需要看单个字段。“截止时间必须晚于开始时间”需要同时看两个字段，属于跨字段校验。

自定义跨字段校验时，应明确 `null` 由谁处理。通常必填性由字段约束处理，组合校验在所需值存在时再比较，避免“本来想返回友好校验错误，结果校验器自己抛空指针”。

### 10.2 业务规则不应全部放在 DTO 校验中

“设备是否存在”、“工单当前是否允许指派”需要业务状态或数据查询。这些规则应位于应用服务或领域模型中，不要把校验注解变成隐藏的业务服务。

## 11. Controller、应用服务和领域对象的分工

可以把一次请求看成几次转换：

```text
HTTP 请求
   ↓ Controller：理解路由、header、DTO 和状态码
应用用例输入
   ↓ Application Service：编排一次完整用例
领域对象
   ↓ Domain：维护状态和业务不变条件
Repository / 外部端口
```

例如“指派工单”的应用服务可能：

1. 根据 ID 加载工单；
2. 让工单对象执行 `assignTo(technicianId)`；
3. 保存更新后的工单；
4. 返回用例结果。

Controller 不应直接操作 Mapper，否则 HTTP 层就同时掌握 SQL 查询、事务和业务状态。Service 也不应只是为每个 Mapper 方法原样转发一次；它的边界应与完整业务用例对齐。

## 12. 状态码要表达结果类别

常用状态码的概念分类：

| 状态码 | 常见含义 |
| --- | --- |
| `200 OK` | 请求成功，响应有正常内容 |
| `201 Created` | 成功创建新资源 |
| `204 No Content` | 成功，不需要返回 body |
| `400 Bad Request` | 请求格式、绑定或通用校验错误 |
| `401 Unauthorized` | 当前请求没有有效认证 |
| `403 Forbidden` | 已识别身份，但不允许执行 |
| `404 Not Found` | 目标资源不存在或不可见 |
| `409 Conflict` | 请求与当前资源状态冲突 |
| `415 Unsupported Media Type` | 请求 body 格式不支持 |
| `500 Internal Server Error` | 服务端未预期故障 |

不要为了“前端好处理”就将所有结果都包在 `200 OK` 中。HTTP 客户端、代理、监控和缓存都会根据状态码理解结果。“HTTP 200，body 中 code=500”是另造一套不完整协议。

## 13. 用 Problem Details 统一错误结构

错误不应有时是纯字符串，有时是异常堆栈，有时又是一组随机字段。Problem Details 提供一种标准错误形状：

```json
{
  "type": "https://factorycare.example/problems/work-order-conflict",
  "title": "Work order state conflict",
  "status": 409,
  "detail": "A completed work order cannot be reassigned",
  "instance": "/api/work-orders/WO-9001/assignee"
}
```

主要字段：

- `type`：错误类型的稳定标识，可指向说明文档；
- `title`：该类错误的简短名称；
- `status`：HTTP 状态码；
- `detail`：本次具体失败的说明；
- `instance`：识别本次请求或问题实例。

可增加业务所需的扩展字段，例如字段校验列表或请求关联 ID，但应保持结构和字段语义稳定。

### 13.1 统一异常映射

Spring MVC 可用 `@RestControllerAdvice` 和 `@ExceptionHandler` 将不同异常映射到稳定 HTTP 错误：

```java
@RestControllerAdvice
class ApiExceptionHandler {

    @ExceptionHandler(WorkOrderNotFoundException.class)
    ProblemDetail handleNotFound(WorkOrderNotFoundException exception) {
        ProblemDetail problem =
                ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND,
                        exception.getMessage());
        problem.setTitle("Work order not found");
        return problem;
    }
}
```

这样 Controller 不需要每个方法重复 `try/catch`。应用服务可以用应用语言抛出“工单不存在”或“状态冲突”，Web 边界再决定它们如何表达为 HTTP。

### 13.2 客户端错误和服务端日志不是同一份内容

客户端需要稳定、可操作的错误，不需要 Java 堆栈、SQL、文件绝对路径和密钥。服务端日志需要保留诊断用 cause 链和关联 ID，但同样需要脱敏。

```text
对外：稳定错误类型 + 安全详情 + requestId
对内：完整 cause 链 + 上下文 + requestId
```

两者通过关联 ID 对应，而不是把内部异常原样发给客户端。

## 14. 分页、排序与过滤也是契约

列表 API 如果不限制数量，数据增长后会同时拖垮数据库、服务端内存和网络。

### 14.1 偏移分页

```http
GET /api/work-orders?page=3&size=20
```

它容易理解和跳页，但数据在翻页期间新增或删除时，可能出现重复或遗漏；很深的 offset 也可能越来越贵。

### 14.2 游标分页

```http
GET /api/work-orders?after=opaque-cursor&limit=20
```

游标表示上一页的稳定排序位置，常更适合持续滚动和大数据集。游标应被当作不透明值，客户端不应解析它的内部格式。

无论哪种分页，都需要稳定排序。只按可重复的 `createdAt` 排序时，可加唯一 ID 作为次排序键：

```text
ORDER BY created_at DESC, id DESC
```

允许客户端传排序字段时，服务端应将其映射到白名单，不要把外部字符串直接拼进 SQL。

## 15. 缓存条件与 API 版本

响应可通过 `ETag` 表示当前资源版本。客户端再次请求时携带：

```http
If-None-Match: "work-order-42-v7"
```

如果资源未变，服务端可返回 `304 Not Modified`，省去重复 body。条件请求也可用于避免客户端用旧版本覆盖新数据。

API 版本不应因每次增加字段就立即提升。先区分：

- 对现有客户端兼容的扩展；
- 客户端必须修改才能继续工作的破坏性变更。

版本可以通过 URL、header 或媒体类型表达。具体方式没有脱离系统环境的唯一答案，但必须有发布、废弃和观测老客户端的方法。

## 16. 一次完整请求的心智模型

```text
客户端发送 HTTP 请求
  ↓
路由匹配 Controller
  ↓
path/query/header 绑定 + body JSON 转 DTO
  ↓
DTO 结构校验
  ↓
Controller 转成应用用例输入
  ↓
Application Service 编排业务对象和端口
  ↓
成功：结果转响应 DTO + 正确状态码
失败：异常在 Web 边界映射为 Problem Details
  ↓
HTTP 响应返回客户端
```

这篇需要建立的不是“哪个注解怎么写”的孤立记忆，而是三条边界：

1. HTTP/JSON 是外部契约，不等于内部领域模型；
2. Controller 做协议转换，Application Service 编排用例，领域对象维护业务规则；
3. 成功契约和失败契约同样需要稳定设计。
