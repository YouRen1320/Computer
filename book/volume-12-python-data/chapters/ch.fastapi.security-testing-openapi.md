---
schema_version: 2
edition: 2026.2-draft
id: ch.fastapi.security-testing-openapi
title: FastAPI 安全集成、测试与 OpenAPI 合同
responsibility: 集成认证/授权依赖、异步测试和 OpenAPI 合同，覆盖未认证、越权与错误 Schema，不重教通用身份或 Web 威胁模型。
volume: '12'
order: 17
level: L3
status: drafting
path: book/volume-12-python-data/chapters/ch.fastapi.security-testing-openapi.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.testing-logging-debug
- ch.python.asyncio-cancellation
- ch.fastapi.web-foundations
- ch.security.session-authentication
version_surfaces:
- python-3.14
- fastapi
- pytest
- pydantic-2
- openapi
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“FastAPI 安全集成、测试与 OpenAPI 合同”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - fastapi-security-testing
  - fastapi-openapi-contract
  covers_topics:
  - fastapi.security-dependency
  - fastapi.current-principal
  - fastapi.authorization-dependency
  - fastapi.async-test-client
  - fastapi.security-negative-test
  - fastapi.openapi-generation
  - fastapi.operation-id
  - fastapi.security-scheme
  - fastapi.schema-example
  - fastapi.openapi-diff
  uses_capabilities:
  - python.testing-debugging
  - python.asyncio-cancellation
  - security.authentication
  - security.web-threat
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“FastAPI 安全集成、测试与 OpenAPI 合同”构建可运行程序与测试：为工单 API 接入认证依赖、异步安全测试和 OpenAPI 契约差异检查；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - fastapi-security-testing
  - fastapi-openapi-contract
  covers_topics:
  - fastapi.security-dependency
  - fastapi.current-principal
  - fastapi.authorization-dependency
  - fastapi.async-test-client
  - fastapi.security-negative-test
  - fastapi.openapi-generation
  - fastapi.operation-id
  - fastapi.security-scheme
  - fastapi.schema-example
  - fastapi.openapi-diff
  uses_capabilities:
  - python.testing-debugging
  - python.asyncio-cancellation
  - security.authentication
  - security.web-threat
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: pytest-async-integration-auth-negative-matrix-openapi-diff
- id: diagnose
  kind: fault-diagnosis
  text: 面对“依赖覆盖漏清理、只测成功授权或文档 Schema 与运行响应漂移”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - fastapi-security-testing
  - fastapi-openapi-contract
  covers_topics:
  - fastapi.security-dependency
  - fastapi.current-principal
  - fastapi.authorization-dependency
  - fastapi.async-test-client
  - fastapi.security-negative-test
  - fastapi.openapi-generation
  - fastapi.operation-id
  - fastapi.security-scheme
  - fastapi.schema-example
  - fastapi.openapi-diff
  uses_capabilities:
  - python.testing-debugging
  - python.asyncio-cancellation
  - security.authentication
  - security.web-threat
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# FastAPI 安全集成、测试与 OpenAPI 合同

> 本章不重新教授密码、Session、OIDC、JWT 或通用 Web 威胁模型，而是回答集成问题：已经有可信身份系统时，FastAPI 如何把凭据变成当前主体、怎样在每条受保护路径执行授权、如何用负例矩阵证明失败关闭，以及怎样让 OpenAPI 文档与运行时安全合同保持一致。真实 FactoryCare 的身份与业务授权仍由 Java 负责，Python 不签发自己的第二套用户身份。

## 1. 认证、当前主体与授权是三步

```text
请求凭据
  -> 认证：凭据是否有效，代表谁？
  -> 当前主体：主体 ID、租户、角色/权限、有效期等最小上下文
  -> 授权：这个主体能否对这个资源执行这个动作？
```

认证成功不等于授权成功。一个有效维修人员 token 不一定能读取另一个租户的工单；一个管理员身份也不应自动拥有未定义的跨租户权限。

在 FastAPI 中，三步常表示为依赖链：

```python
credentials -> current_principal -> require_permission -> path operation
```

依赖是集成位置，不是安全证明。若依赖漏挂在一条路由上，或内部函数可绕过它，接口仍会越权。因此需要结构审查、OpenAPI security 检查与运行时负例共同守护。

## 2. FastAPI Security 工具提供什么

FastAPI 提供 `fastapi.security` 中的凭据提取工具，例如 `HTTPBearer`、`OAuth2PasswordBearer`、`APIKeyHeader`。它们可：

- 从约定 Header/Cookie/Query 提取凭据；
- 在缺失或格式错误时产生 HTTP 错误（取决于 auto_error）；
- 把安全方案写进 OpenAPI；
- 与 `Depends` / `Security` 组合。

它们通常不替你完成完整 token 密码学验证、吊销、issuer/audience 检查、权限查询或租户隔离。

```python
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

bearer = HTTPBearer(auto_error=False)
```

`auto_error=False` 让依赖自己统一 401 信封；代价是必须明确处理 None，漏处理就可能把匿名当合法。若使用默认自动错误，要验证当前版本返回状态码和 Header，而不是凭旧教程记忆。

## 3. 从凭据建立 current principal

先定义最小内部主体：

```python
from pydantic import BaseModel, ConfigDict


class Principal(BaseModel):
    model_config = ConfigDict(frozen=True)

    subject: str
    tenant_id: str
    permissions: frozenset[str]
```

主体不是完整用户档案，不应携带密码哈希、原 token、无关个人信息。依赖：

```python
from typing import Annotated
from fastapi import Depends, HTTPException, status


async def current_principal(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer),
    ],
) -> Principal:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return await verified_identity_client.resolve(credentials.credentials)
```

`resolve` 必须执行已确认身份合同：签名/issuer/audience/有效期/吊销或受信内省等。绝不能只做 Base64 解码就信任 JWT payload；解码不是验证。也不能把客户端传来的 `X-User-Id` 直接当主体，除非受信代理、网络边界和防伪合同已经独立落实。

### 3.1 失败要关闭

身份服务超时或响应无法验证时，不应降级为匿名有权或“先放行”。根据内部合同返回 401/503，并记录不含 token 的观测信息。缓存身份结果必须短期、有作用域、尊重吊销与密钥轮换，不能为了性能永久信任。

### 3.2 本章资产的假 token

离线实验用固定字符串映射到 Principal，仅为测试依赖与路由：

```text
training-reader -> 有 read:suggestions
training-denied -> 已认证但无权限
training-expired -> 认证失败
```

这不是 token 设计、签发或验证范例，禁止复制到部署。资产明确未连接外部 IdP，也没有证明任何 JWT/OIDC 行为。

## 4. 授权依赖

可用依赖工厂表达所需权限：

```python
from collections.abc import Callable


def require_permission(permission: str) -> Callable[..., Principal]:
    async def authorize(
        principal: Annotated[Principal, Depends(current_principal)],
    ) -> Principal:
        if permission not in principal.permissions:
            raise HTTPException(status_code=403, detail="forbidden")
        return principal

    return authorize
```

路由声明：

```python
CanReadSuggestions = Annotated[
    Principal,
    Depends(require_permission("ai:suggestion:read")),
]


@router.get("/suggestions/{suggestion_id}")
async def read_suggestion(
    suggestion_id: str,
    principal: CanReadSuggestions,
): ...
```

授权必须在读取/返回资源之前执行，并且包含资源级条件：

```python
if suggestion.tenant_id != principal.tenant_id:
    raise HTTPException(status_code=404, detail="not found")
```

使用 403 还是 404 隐藏资源存在性是产品安全合同，必须一致测试。不能只检查角色字符串然后忽略 tenant_id、资源所有者、状态和动作。

## 5. FactoryCare 的正确安全拓扑

真实拓扑：

```text
终端用户 -> Java /api/v1
             |
             | Java 已认证主体、授权后的最小内部请求
             v
          Python /internal/v1
```

重要约束：

- Vue、uni-app、Flutter 不直接调用 Python；
- Java 验证终端会话、RBAC、租户和数据权限；
- Java 调 Python 使用单独服务身份和固定内部合同；
- Python 仍验证调用方服务身份与最小作用域，不能因为在内网就裸奔；
- Python 工具回调只读、固定、受限，并由 Java 重新授权；
- Python 只返回建议/派生结果，不确认派工、关闭工单或发布知识。

因此本章的 `Principal` 在生产中更可能是内部服务主体和被委托的最小上下文，不是 Python 自己管理的完整终端用户表。

## 6. 401、403 与 404

- 401：没有有效认证；Bearer 场景通常返回 `WWW-Authenticate: Bearer`；
- 403：主体有效，但缺少动作权限；
- 404：资源不存在，或合同选择隐藏无权资源的存在。

不要把 token 过期、权限不足和资源不存在全部返回 200。也不要在 401 detail 中暴露签名算法、key ID、内省地址或具体账号状态。

错误信封可以稳定：

```json
{
  "code": "AUTHENTICATION_REQUIRED",
  "message": "authentication required"
}
```

客户端依赖 code，不应解析自然语言。内部日志用请求 ID 记录失败阶段，但 token 只记录不可逆指纹或完全不记录。

## 7. 安全依赖必须进入 OpenAPI

如果路由使用 `HTTPBearer`/`OAuth2...` 作为依赖，FastAPI 会生成 `components.securitySchemes` 和 operation 的 `security` 要求。文档工具可显示 Authorize，并让生成客户端知道凭据方案。

```python
schema = app.openapi()
assert "HTTPBearer" in schema["components"]["securitySchemes"]
assert schema["paths"][path]["get"]["security"]
```

但 OpenAPI security 不是运行时防火墙。可能出现两种漂移：

1. 文档声明安全，代码却没执行授权；
2. 代码手工读取 Header，运行时安全但 OpenAPI 没有 security scheme。

两种都要修。测试应同时发匿名请求并检查 schema，不能只看 Swagger UI 有锁图标。

## 8. TestClient 与异步 HTTPX 测试

同步测试：

```python
from fastapi.testclient import TestClient


def test_anonymous_is_rejected():
    with TestClient(app) as client:
        response = client.get("/internal/v1/suggestions/S-1")
    assert response.status_code == 401
```

当测试还需 await 异步 repository/client 时，使用 HTTPX：

```python
import pytest
from httpx import ASGITransport, AsyncClient


@pytest.mark.anyio
async def test_allowed_reader():
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/internal/v1/suggestions/S-1",
            headers={"Authorization": "Bearer training-reader"},
        )
    assert response.status_code == 200
```

FastAPI 官方文档明确提醒：HTTPX AsyncClient + ASGITransport 不会自动触发 lifespan。若应用依赖启动/关闭资源，应使用专门 lifespan 管理器或应用工厂，并有对应测试。不能因为进程内请求成功就声称真实启动流程已验证。

### 8.1 固定 AnyIO backend

AnyIO pytest 插件可能在多个 backend 运行。若实验只安装 asyncio，可提供 fixture：

```python
@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"
```

这不是证明 trio 兼容。测试报告应写明实际 backend。事件循环相关资源在正确 async 生命周期内创建，避免“attached to a different loop”。

## 9. 异步测试的任务所有权

安全依赖可能调用身份内省和权限服务。测试要控制超时、取消和未完成任务：

- AsyncClient 用 async with 关闭；
- 创建的 Task 由 fixture/函数持有并 await 或 cancel 后 await；
- 不用固定 sleep 等待并发结果；
- 超时后断言下游是否取消或被有界回收；
- 不吞 `CancelledError` 后返回成功授权；
- 测试结束检查无后台异常。

ASGI 进程内测试并不自动模拟客户端断连、代理超时或多 worker；这些留给更高层验证。

## 10. 安全负例矩阵

只测一个合法 token 是严重缺口。至少覆盖：

| 场景 | 预期 | 关键证据 |
| --- | ---: | --- |
| 无 Authorization | 401 | `WWW-Authenticate`，路由未执行 |
| scheme 错误 | 401 | 不把 Basic 当 Bearer |
| token 格式损坏 | 401 | 不泄露解析细节 |
| token 过期 | 401 | 不使用过期主体 |
| issuer/audience 不符 | 401 | 身份验证失败关闭 |
| 主体有效、缺权限 | 403 | repository/动作未执行 |
| 权限有、租户不符 | 404/403 | 无资源内容泄露 |
| 权限与租户均正确 | 200 | 精确响应模型 |
| 身份服务超时 | 503/401（按合同） | 不放行、不泄露 token |
| 依赖抛未预期异常 | 500 | 安全信封、内部日志关联 |

每个失败测试还应验证副作用为零。例如越权 PATCH 不仅要返回 403，还要断言 repository 未写入。

### 10.1 错误身份不能只靠假 token

离线 fixture 只能证明应用如何处理依赖返回/失败。签名、JWK 轮换、clock skew、nonce、PKCE、吊销和真实 IdP 错误必须在专门集成环境验证。本章不伪造这些证据。

## 11. 依赖覆盖的安全陷阱

```python
app.dependency_overrides[current_principal] = lambda: allowed_principal
```

覆盖可让业务授权测试稳定，也会绕过凭据提取与认证。必须有两组测试：

1. 不覆盖 current_principal，走匿名/假凭据失败矩阵；
2. 覆盖为精确主体，测试资源级授权与业务响应。

覆盖后清理：

```python
previous = dict(app.dependency_overrides)
try:
    app.dependency_overrides[current_principal] = override
    ...
finally:
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous)
```

若漏清理，后续“匿名应 401”可能因前一测试留下管理员主体而返回 200。测试单独运行通过、整套顺序运行失败是典型证据。应用工厂能进一步隔离实例。

## 12. OpenAPI 是机器可读合同

FastAPI 默认从路由、参数、Pydantic 模型、响应模型和安全依赖生成 OpenAPI：

```python
schema = app.openapi()
```

重点结构：

```text
openapi
info
paths
  /internal/v1/suggestions/{suggestion_id}
    get
      operationId
      parameters
      responses
      security
components
  schemas
  securitySchemes
```

`/openapi.json` 是否对外公开是部署决策。关闭 docs URL 不等于 API 安全；公开文档也不能替代认证。内部 schema 可以作为构建产物供 Java/客户端/契约测试使用。

## 13. operationId 必须稳定且唯一

客户端生成器常把 operationId 变成方法名。自动生成结果可能受函数名、router 和框架版本影响。关键接口可显式设置：

```python
@router.get(
    "/suggestions/{suggestion_id}",
    operation_id="getAiSuggestion",
)
async def read_suggestion(...): ...
```

要求：全 schema 唯一、可读、跨内部重构稳定。重复 operationId 会让代码生成冲突；改 operationId 即使路径没变，也可能是客户端破坏性变更。

可在测试中收集所有 operationId：

```python
operation_ids = []
for path_item in schema["paths"].values():
    for method in ("get", "post", "put", "patch", "delete"):
        if method in path_item:
            operation_ids.append(path_item[method]["operationId"])
assert len(operation_ids) == len(set(operation_ids))
```

## 14. Schema 示例是文档，不是测试替身

Pydantic 可用 `json_schema_extra` 提供模型示例，FastAPI 参数也可提供 OpenAPI examples。示例应：

- 符合当前 Schema；
- 使用虚构、非敏感数据；
- 包含常见成功输入；
- 必要时解释错误示例，但不混进默认成功模型；
- 在模型变更时由测试重新校验。

```python
class SuggestionResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"id": "S-1", "hint": "REVIEW_SOON"}
            ]
        }
    )

    id: str
    hint: str
```

示例能显示在文档，但不会自动证明运行接口返回它。测试要请求实际 endpoint，并用响应模型/JSON Schema 或精确断言验证。

## 15. OpenAPI diff：先规范化，再分类

把 `app.openapi()` 以稳定 JSON 保存为基线：

```python
json.dumps(schema, ensure_ascii=False, sort_keys=True, indent=2)
```

diff 前去除真正非合同的噪声，但不要一股脑删除 description、security 或 examples。变更分类：

### 15.1 常见破坏性变化

- 删除路径或方法；
- 新增必填请求字段；
- 缩小允许枚举/范围；
- 删除响应字段或改变类型；
- 改成功状态码；
- 改 operationId；
- 移除/改变 security scheme；
- 把可选认证变成必需或反之却未版本化；
- 错误响应 Schema 漂移。

### 15.2 可能兼容但仍需审查

- 新增可选请求字段；
- 新增响应字段（严格客户端可能仍受影响）；
- 新增 endpoint；
- 修改说明或示例；
- 增加新的错误响应。

不能只按文本行数决定 breaking。应解析结构，按团队兼容策略分类，并允许人工审查明确例外。

## 16. 运行响应与文档 Schema 双向验证

只快照 OpenAPI 会出现“文档自洽、实现错误”。组合测试：

1. 从 schema 确认 endpoint、operationId、security 和 response `$ref`；
2. 发匿名/越权/成功请求；
3. 检查实际状态码和 JSON；
4. 用 Pydantic 响应模型重新验证成功 JSON；
5. 比较错误信封字段；
6. 确认文档未声明实际不存在的成功/错误分支。

Response model 一般会让运行时和文档共享来源，但直接返回 `Response`、自定义 handler、条件响应或手工 `openapi_extra` 仍可漂移。

## 17. OpenAPI security 的典型误区

### 17.1 只在文档写 security

手工 `openapi_extra={"security": ...}` 只改变文档，不执行依赖。匿名运行测试会揭穿。

### 17.2 只手工读 Header

运行时可能拒绝匿名，但 schema 没 securitySchemes，生成客户端不会携带凭据。使用 FastAPI security 依赖或正确扩展 schema，并测试二者一致。

### 17.3 全局依赖遮蔽公共端点

把认证加到整个 app 会连 health/public metadata 都保护。是否正确取决于合同。按 router/operation 分组，并测试哪些路径应公开。

### 17.4 Swagger Authorize 被当成生产认证

交互文档只是客户端 UI。它不会替代 TLS、token 验证、CSRF/CORS 策略、授权和 secret 管理。

## 18. 安全日志和可观测性

记录：

- request/trace ID；
- 认证失败类别（不含原凭据）；
- 主体内部稳定 ID 的受控表示；
- 权限名、资源类型、决策结果；
- 身份服务延迟/超时；
- OpenAPI 基线版本与 diff 结果。

不要记录：

- Authorization Header；
- Session cookie；
- 密码/验证码；
- 完整 JWT payload；
- 个人数据与请求 Body；
- 内部堆栈到客户端。

日志本身受访问控制、保留和脱敏约束。测试 fixture 使用假 token，避免安全扫描把真实 secret 提交到仓库。

## 19. 故障诊断

### 19.1 覆盖漏清理

表现：匿名测试单独运行 401，整套运行却 200。检查 `app.dependency_overrides` 在测试前后的键集合；定位哪个 fixture 写入但没有 finally/yield 清理。修复后随机顺序或连续运行两次。

### 19.2 只测成功授权

表现：coverage 很高，却无法回答过期、错租户或缺权限会怎样。建立表驱动负例，每一行断言状态、错误 code、Header 和零副作用。不能靠一个 403 代表所有安全分支。

### 19.3 文档与响应漂移

表现：OpenAPI 声明字段 `hint`，实际返回 `recommendation`；或文档无 401。第一可信证据是结构 diff 与实际响应 JSON。确认权威合同后同时修模型/handler/test，不能只改快照接受意外变更。

### 19.4 安全方案存在但路由未保护

schema components 有 HTTPBearer，不表示每个 operation 使用它。逐操作检查 `security`，并对受保护路径发匿名请求。

## 20. 发布门

FastAPI 内部接口发布前至少满足：

- 依赖版本和 lockfile 固定；
- 身份系统信任边界有 ADR；
- 每个受保护 operation 声明并执行安全依赖；
- 匿名、过期、错误身份、无权限、错租户和允许矩阵通过；
- 失败请求无写副作用；
- OpenAPI security scheme 与 operation security 一致；
- operationId 唯一稳定；
- 当前 schema 与批准基线完成 breaking diff；
- 实际响应与 schema 双向验证；
- 日志不含凭据；
- 真实 IdP/代理/网络未验证项明确阻塞生产结论；
- Java/Python 权限和事实所有权边界未改变。

“Swagger 能点通”不是发布证据。

## 21. 与 Spring Security/OpenAPI 对照

- FastAPI security dependency 类似 Spring Security 过滤链/方法授权的部分集成效果，但没有自动复制其安全上下文和成熟默认值；
- Principal 是请求内可信主体，不是随便从 Header 构造的 DTO；
- `app.dependency_overrides` 类似测试替换 Bean/组件，但全局可变状态污染方式不同；
- `app.openapi()` 类似 springdoc 输出，但生成细节和 response model 来源不同；
- pytest + HTTPX AsyncClient 与 MockMvc/WebTestClient 都能做进程内测试，却不证明真实部署网络；
- Python async 取消与 Java 线程/响应式取消模型不能直接互换。

对照用于复用概念，不得据此跳过 FastAPI 实际负例。

## 22. 学习与验收顺序

1. 画出 credentials→principal→authorization→resource 的依赖链；
2. 写无凭据、格式错误、过期、无权限和允许五个预测；
3. 用固定训练 token 实现离线依赖，不声称 JWT/OIDC；
4. TestClient 跑同步矩阵；
5. HTTPX AsyncClient + pytest AnyIO 跑异步矩阵并固定 backend；
6. 覆盖 principal 测资源级授权，并证明覆盖清理；
7. 检查每个受保护 operation 的 security；
8. 固定 operationId 与 Schema 示例；
9. 注入 schema/运行响应漂移，让结构 diff 阻断；
10. 口述为何 Python 不能成为第二身份与业务事实后端。

学习者必须能解释每个失败在哪一层被拒绝、是否执行了 repository、什么证据尚未取得。

## 23. 章末检查

你应能回答：

- FastAPI security 工具提取凭据与验证 token 有何差别？
- current principal 最少包含什么，绝不能包含什么？
- 为什么认证成功不等于资源授权？
- 401、403、404 如何按合同选择？
- OpenAPI 有 security scheme 为何仍可能匿名可访问？
- AsyncClient 为什么不自动证明 lifespan？
- 依赖覆盖如何污染后续安全测试？
- 负例矩阵为何还要断言零副作用？
- operationId 为什么属于兼容合同？
- Schema example 为什么不能替代运行测试？
- 哪些 OpenAPI diff 属于破坏性？
- 本章假 token 为什么不能成为线上 IdP 证据？
- Java 与 Python 的身份、授权、事实边界是什么？

## 24. 版本、官方资料与未验证范围

本章沿用同批可复现实验组合：FastAPI 0.139.2、Pydantic 2.13.4、Starlette 1.3.1、HTTPX 0.28.1、pytest 9.1.1、AnyIO 4.14.2、CPython 3.14.3；核对日期 2026-07-24。

- [FastAPI Security First Steps](https://fastapi.tiangolo.com/tutorial/security/first-steps/)
- [FastAPI Testing Dependencies with Overrides](https://fastapi.tiangolo.com/advanced/testing-dependencies/)
- [FastAPI Async Tests](https://fastapi.tiangolo.com/advanced/async-tests/)
- [FastAPI OpenAPI Docs](https://fastapi.tiangolo.com/reference/openapi/docs/)
- [FastAPI Generating SDKs](https://fastapi.tiangolo.com/advanced/generate-clients/)
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)

已验证：固定假凭据的进程内认证/授权负例、TestClient、HTTPX ASGITransport、pytest AnyIO asyncio backend、依赖覆盖清理、security scheme、operation security、operationId 唯一、示例和结构 diff。未验证：外部 IdP、JWT 签名/JWK 轮换、OIDC discovery、Session、真实 Java 委托、TLS/代理、lifespan、真实数据库、跨进程缓存、多 worker、网络取消、负载、线上 OpenAPI 暴露策略。任何这些未验证项都不能从离线绿色测试推断为可用。
