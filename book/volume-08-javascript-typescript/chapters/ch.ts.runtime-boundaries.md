---
schema_version: 2
edition: 2026.2-draft
id: ch.ts.runtime-boundaries
title: 运行时 Schema、类型边界与 TypeScript 质量工具链
responsibility: 在网络、存储和环境变量边界执行运行时 Schema 校验，并组合严格编译、lint、格式与测试门禁，不把类型声明当外部数据证据。
volume: '08'
order: 18
level: L2+
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.ts.runtime-boundaries.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ts.modeling-narrowing
- ch.js.fetch-cancellation-race
version_surfaces:
- typescript
- node-24-lts
- pnpm
- vitest
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“运行时 Schema、类型边界与 TypeScript 质量工具链”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - ts-runtime-schema
  - ts-quality-toolchain
  covers_topics:
  - ts.runtime-schema
  - ts.parse-safeparse
  - ts.schema-inferred-type
  - ts.untrusted-boundary
  - ts.strict-compiler-options
  - ts.lint-format-boundary
  - ts.typecheck-test-build-order
  - ts.generated-type-review
  uses_capabilities:
  - web.typescript-types
  - web.javascript-testing-debugging
  - web.javascript-network-race
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单 API 建立运行时 Schema、严格类型和可失败质量脚本；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - ts-runtime-schema
  - ts-quality-toolchain
  covers_topics:
  - ts.runtime-schema
  - ts.parse-safeparse
  - ts.schema-inferred-type
  - ts.untrusted-boundary
  - ts.strict-compiler-options
  - ts.lint-format-boundary
  - ts.typecheck-test-build-order
  - ts.generated-type-review
  uses_capabilities:
  - web.typescript-types
  - web.javascript-testing-debugging
  - web.javascript-network-race
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: typecheck-vitest-unit-invalid-payload-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“直接断言响应类型、忽略 parse 失败或质量脚本顺序错误造成的假通过”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ts-runtime-schema
  - ts-quality-toolchain
  covers_topics:
  - ts.runtime-schema
  - ts.parse-safeparse
  - ts.schema-inferred-type
  - ts.untrusted-boundary
  - ts.strict-compiler-options
  - ts.lint-format-boundary
  - ts.typecheck-test-build-order
  - ts.generated-type-review
  uses_capabilities:
  - web.typescript-types
  - web.javascript-testing-debugging
  - web.javascript-network-race
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 运行时 Schema、类型边界与 TypeScript 质量工具链

> TypeScript 只检查编译时能看到的代码。HTTP 响应、localStorage、环境变量、postMessage、文件和第三方 SDK 在运行时仍是未知输入。进入可信业务区域前必须校验；校验成功后再让类型系统继续保护程序。

## 1. 类型声明不是运行时证据

下面的写法能让编辑器提示字段，却没有验证服务器真的返回该结构：

```ts
interface WorkOrder {
  id: string
  status: 'ASSIGNED' | 'IN_PROGRESS' | 'CLOSED'
  priority: number
}

const response = await fetch('/api/v1/work-orders/WO-101')
const order = (await response.json()) as WorkOrder
console.log(order.status.toLowerCase())
```

`as WorkOrder`是一条给编译器的断言，运行时不会插入检查。如果响应是 `{ "status": null }`、登录页 HTML、旧版本字段或攻击者控制内容，代码仍会继续，直到更远的位置抛出难以定位的错误。

边界设计的目标是把失败尽量靠近输入点：

```text
HTTP bytes -> HTTP status -> JSON decode -> runtime schema -> trusted WorkOrder
```

每一箭头都有不同失败：网络中断、非 2xx、JSON 语法错误、结构/业务约束不符。不能把它们全部包装成“请求失败”，也不能把 JSON 解码成功等同于业务数据有效。

## 2. 哪些地方是不可信边界

“不可信”不是指恶意，而是指当前 TypeScript 编译器无法证明其值符合合同。常见边界：

- `response.json()`的返回值；
- localStorage、sessionStorage、IndexedDB 中的旧版本或手工修改数据；
- `process.env`、Vite `import.meta.env`和部署平台注入值；
- URL 参数、表单、拖入文件和剪贴板；
- `postMessage`、WebSocket、SSE 与 Service Worker 消息；
- 第三方 SDK callback、原生桥、uni-app/Flutter channel；
- JSON/YAML 配置、CSV、用户导入文件；
- 代码生成产物与实际运行服务版本不一致时的响应。

内部函数之间不需要每层重复 Schema。校验应放在数据进入受信任域的入口，输出确定类型；域内使用 TypeScript、构造函数和业务不变量。跨进程、跨持久化版本或跨权限边界时再校验。

## 3. 手写守卫与 Schema 库

简单边界可以写 type predicate：

```ts
function isWorkOrder(value: unknown): value is WorkOrder {
  if (typeof value !== 'object' || value === null) return false
  if (!('id' in value) || typeof value.id !== 'string') return false
  return true
}
```

它适合字段少、规则稳定且团队愿意维护测试的场景。复杂嵌套、联合、错误路径、转换和类型推导时，Schema 库更系统。本章用 Zod 4 演示，但原则不绑定某个库。

选择库时比较：运行时/包体、浏览器与 Node 支持、错误结构、异步 refinement、转换语义、对象额外键策略、JSON Schema/OpenAPI 互操作、tree shaking 和团队熟悉度。不要因为 AI 最会写某个库就直接决定架构。

## 4. 一个严格的工单 Schema

```ts
import * as z from 'zod'

const WorkOrderStatusSchema = z.enum([
  'CREATED',
  'TRIAGED',
  'ASSIGNED',
  'ACCEPTED',
  'IN_PROGRESS',
  'PENDING_PARTS',
  'PENDING_APPROVAL',
  'RESOLVED',
  'VERIFIED',
  'CLOSED',
  'REOPENED',
  'CANCELLED',
])

export const WorkOrderSchema = z.strictObject({
  id: z.string().regex(/^WO-[0-9]+$/),
  title: z.string().trim().min(1).max(200),
  status: WorkOrderStatusSchema,
  priority: z.int().min(1).max(5),
  createdAt: z.iso.datetime({ offset: true }),
  assigneeId: z.int().positive().nullable(),
})

export type WorkOrder = z.infer<typeof WorkOrderSchema>
```

Schema 是运行时可执行值，`z.infer`从它推导静态类型，减少“接口改了但 Schema 忘了改”的双源。它仍不能自动证明 Java OpenAPI 与前端 Schema 一致，契约测试和生成流程需要另一个证据层。

使用 `strictObject`明确额外字段是失败。在兼容演进中是否拒绝未知字段是设计选择：响应 DTO 若服务端会向后兼容地增加字段，前端严格拒绝可能造成不必要故障；安全配置或命令对象则可能需要严格。Zod 4 也提供普通对象或 loose 策略，选择必须写入合同和测试。

Schema 中 `.trim()`、coerce、transform 会改变输出。此时输入类型与输出类型不同，应区分 `z.input<typeof Schema>`和 `z.output<typeof Schema>`；不能假设解析只检查不转换。

## 5. `parse` 与 `safeParse`

`parse(input)`成功时返回已解析值，失败时抛 `ZodError`，适合本层采用异常流程且有统一捕获：

```ts
const order = WorkOrderSchema.parse(payload)
```

`safeParse(input)`返回判别联合，适合显式映射为应用错误：

```ts
const parsed = WorkOrderSchema.safeParse(payload)

if (!parsed.success) {
  return {
    ok: false as const,
    error: {
      kind: 'invalid-payload' as const,
      issues: parsed.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        code: issue.code,
      })),
    },
  }
}

return { ok: true as const, value: parsed.data }
```

不要 catch 后返回 `payload as WorkOrder`继续执行，也不要只打印错误然后给空对象。解析失败意味着外部合同被破坏，应进入稳定失败分支：展示可理解错误、记录安全证据、阻止业务写入或降级。

异步 refinement/transform 必须使用 `parseAsync`/`safeParseAsync`。但不要把数据库权限查询塞进客户端 Schema；结构校验与服务端授权是不同职责。

## 6. 错误要稳定、可观察且不泄密

Schema 库错误通常包含路径、代码、期望类型和值相关上下文。应用应该将其映射为稳定错误 DTO：

```ts
type BoundaryIssue = {
  path: string
  code: string
}

type BoundaryResult<T> =
  | { ok: true; value: T }
  | { ok: false; kind: 'invalid-payload'; issues: BoundaryIssue[] }
```

日志保留 endpoint 模板、HTTP status、request id、schema version、issue path/code 和应用版本。默认不要记录完整 payload，因为里面可能有联系方式、故障描述、token 或附件 URL。

用户界面不应显示“Zod invalid_type at [3].assignee.id”。面向用户表达“服务器返回了无法识别的数据，请刷新或联系支持”，开发证据留在受控日志。

## 7. 网络边界的完整顺序

```ts
async function loadWorkOrder(id: string, signal: AbortSignal) {
  const response = await fetch(`/api/v1/work-orders/${encodeURIComponent(id)}`, { signal })

  if (!response.ok) {
    return { ok: false as const, kind: 'http' as const, status: response.status }
  }

  let payload: unknown
  try {
    payload = await response.json()
  } catch {
    return { ok: false as const, kind: 'invalid-json' as const }
  }

  const parsed = WorkOrderSchema.safeParse(payload)
  if (!parsed.success) {
    return { ok: false as const, kind: 'invalid-payload' as const }
  }

  return { ok: true as const, value: parsed.data }
}
```

顺序很重要。先检查 `response.ok`，避免把 401 错误体当 WorkOrder；JSON 解码单独处理；Schema 失败与传输失败分开；AbortError 仍保留取消语义。重试策略只能根据幂等性和故障种类决定，Schema 失败通常不是立即重试能修复。

## 8. 存储与版本迁移

localStorage 保存的是过去某版应用写入的字符串，读取时仍应视为 unknown：

1. 读取字符串；
2. JSON parse；
3. 校验带 `schemaVersion`的外层结构；
4. 若是已知旧版本，执行纯迁移函数；
5. 用当前 Schema 再校验迁移结果；
6. 失败时删除/隔离该缓存并使用安全默认值。

不能通过 `JSON.parse(value) as Settings`跳过。部署回滚、用户手工修改、跨标签页和部分写入都会产生旧/坏数据。迁移函数要有旧版本夹具和幂等测试。

缓存中的服务器实体还涉及过期与权限。Schema 有效只证明结构，不证明成员仍有查看权限或数据仍新鲜。

## 9. 环境变量校验

环境变量在 Node 中通常是 `string | undefined`，前端构建变量也可能缺失或被错误公开。应用启动时一次性解析：

```ts
const EnvSchema = z.strictObject({
  API_BASE_URL: z.url(),
  REQUEST_TIMEOUT_MS: z.coerce.number().int().positive().max(60_000),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
})

export const env = EnvSchema.parse(process.env)
```

现实中 `process.env`含很多平台字段，直接 `strictObject`校验整个对象会因额外键失败；应先挑选应用字段，或采用合适未知键策略。浏览器可见前缀中的变量会进入客户端产物，绝不能放服务端 secret。

启动失败要列缺失键和格式，但不要打印 secret 值。配置错误应尽早阻止应用启动，而不是请求到来后才出现 `undefined` URL。

## 10. 严格 TypeScript 编译选项

`strict: true`开启一组更严格检查，是新项目的合理起点，但不是所有严格选项的全集。常用补充：

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "useUnknownInCatchVariables": true,
    "noEmitOnError": true
  }
}
```

`noUncheckedIndexedAccess`让字典/数组索引结果包含 undefined，迫使检查越界；`exactOptionalPropertyTypes`区分属性缺失与显式 undefined；`noImplicitOverride`让继承覆盖明确。开启后可能暴露大量历史问题，迁移要按模块推进并禁止新代码扩大例外。

不要用项目级 `skipLibCheck`、`any`或双重断言掩盖真实边界问题。`skipLibCheck`有构建速度与第三方声明兼容权衡，并不等于跳过自己代码检查；是否启用需记录原因。

## 11. Lint、格式化、类型检查与测试各管什么

这些工具职责不同：

- formatter 统一排版，减少无意义差异，不证明逻辑正确；
- ESLint/typed lint 发现可疑模式、未处理 Promise、不安全 any 等，不能验证真实输入；
- `tsc --noEmit`验证静态类型关系，不执行代码；
- Vitest 执行运行时行为与非法夹具；
- build 验证打包器、目标平台、资源和生成产物；
- E2E 验证浏览器/服务整合。

“Prettier 通过”不能证明类型正确，“tsc 通过”不能证明 Schema 拒绝坏 JSON，“单元测试通过”也不证明生产构建能解析动态导入。门禁应组合，而不是选择一个当万能检查。

## 12. 门禁顺序与假通过

推荐本地/CI 顺序可按反馈速度排列：

```text
安装锁定依赖 -> 格式检查 -> lint -> typecheck -> 单元测试 -> build -> 集成/E2E
```

具体顺序可以并行优化，但任何必需步骤失败都要使总命令非零退出。常见假通过：

```json
{
  "scripts": {
    "verify": "pnpm typecheck; pnpm test; pnpm build"
  }
}
```

在某些 shell 中分号会继续执行，最后 build 成功可能掩盖前面失败。使用 `&&`、任务运行器 fail-fast 或 CI 独立 job 并正确汇总。Shell 脚本启用 `set -euo pipefail`，管道还要确保前段失败不会丢失。

不要在 verify 中使用 `|| true`、把 coverage/预算标为 allow_failure，或只在开发者电脑运行关键 Schema 测试。

## 13. 生成类型仍需评审

OpenAPI、GraphQL 或数据库工具可以生成 TypeScript 类型，减少手写漂移，但生成文件并不是运行时验证。需要回答：

- 生成来源是否是实际发布合同；
- nullable、optional、缺失和 additionalProperties 映射是否符合语义；
- discriminator 联合是否完整；
- 日期/大整数/decimal 在 JS 运行时如何表示；
- 生成器版本与配置是否锁定；
- diff 是否出现大范围放宽为 `any/unknown`；
- 是否同时生成/复用运行时 validator；
- CI 是否验证生成后工作树无差异。

生成代码可以不逐行手改，但必须审查输入、配置、摘要 diff 和消费边界。不能因为“文件由机器生成”就自动信任。

## 14. 测试矩阵：合法、缺失、额外、错误类型

Schema 测试至少包含：

| 夹具 | 预期 |
| --- | --- |
| 完整合法 WorkOrder | success，输出类型已收窄 |
| 缺失 `status` | 稳定 invalid_type/required 路径 |
| `priority: "5"` | 若未声明 coerce 则失败 |
| 未知 status | enum 失败 |
| 额外 `internalCost` | strict 策略失败 |
| 非法日期 | datetime 失败 |
| `assigneeId: null` | 按合同成功 |
| 整体为数组/null/HTML 字符串 | 根路径失败 |

错误断言优先检查稳定 path/code 和应用错误 kind，少依赖完整英文 message，因为库补丁/locale 可能改变文字。合法输出还要断言 transform/default 行为。

## 15. 三类注入故障

### 15.1 直接断言响应类型

**故障**：`await response.json() as WorkOrder`。

**首个可信证据**：非法夹具能通过边界函数，直到下游访问字段才抛错。搜索 `as WorkOrder`只是线索，行为测试才证明缺口。

**修复**：输入声明为 unknown，执行 Schema；删除绕过；重跑合法与四类非法夹具。

### 15.2 忽略 parse 失败

**故障**：safeParse 失败后返回空对象/旧缓存。

**首个可信证据**：失败分支仍产出 `ok: true`或业务继续执行。日志出现问题但调用者没有错误联合。

**修复**：失败映射为稳定错误结果，调用者穷尽处理；缓存降级必须明确来源和过期，不可静默伪装新数据。

### 15.3 质量脚本顺序错误

**故障**：typecheck 失败但总 verify 退出 0。

**首个可信证据**：CI log 中子命令非零，总 job/脚本却绿色；检查 shell 分隔符和任务依赖图。

**修复**：fail-fast/正确聚合；注入确定类型错误并验证 build 未执行或总命令失败，再恢复并重跑。

## 16. 配套资产

- `examples/encyclopedia/ch.ts.runtime-boundaries/`：真实 Zod 4 Schema、严格 tsc、Vitest 非法夹具和可失败质量脚本；
- `labs/encyclopedia/ch.ts.runtime-boundaries/`：FactoryCare 工单边界与三类故障注入；
- `exercises/encyclopedia/ch.ts.runtime-boundaries/`：公开红灯起点，故意使用断言并漏掉非法负载；
- `solutions-private/encyclopedia/ch.ts.runtime-boundaries/`：同一 oracle 下的参考修复。

执行：

```bash
cd examples/encyclopedia/ch.ts.runtime-boundaries && ./verify.sh
cd ../../../labs/encyclopedia/ch.ts.runtime-boundaries && ./verify.sh
cd ../../../exercises/encyclopedia/ch.ts.runtime-boundaries && ./verify.sh
```

公开练习初始必须失败。不得修改验证器、删除非法夹具或放宽 Schema 获得绿灯。

## 17. AI 生成边界代码的审查

AI 常生成漂亮的 TypeScript interface，然后在 fetch 后 `as ApiResponse`，这是最危险的“看起来类型安全”。要求 AI：

1. 把所有外部输入入口列成表；
2. 输入类型从 unknown 开始；
3. 生成运行时 Schema 与 inferred type；
4. 明确额外字段、coerce、default、nullable 与日期策略；
5. 提供合法及至少四类非法夹具；
6. 解析失败映射稳定错误且不记录敏感 payload；
7. 严格编译、lint、格式、测试、build 任一失败阻断；
8. 解释生成类型与运行时验证为何不同。

审查时重点搜索 `as unknown as`、`any`、catch 后继续、`safeParse(...).data!`、`|| {}`、`|| true`和未 await Promise。AI 可以加速实现，不能替代运行时证据。

## 18. 120 秒口述与独立构建

口述时解释：为什么 TypeScript interface 不检查 JSON；什么是 untrusted boundary；parse 与 safeParse 的差别；Schema inference 如何减少双源；strict、lint、formatter、test、build 各证明什么；生成类型为何仍需评审；如何识别假通过门禁。

不应由本章解决的反例：“确认当前成员是否有权把工单从 RESOLVED 改为 CLOSED。”Schema 能验证命令结构，真正授权和状态机必须由 Java 服务端执行。

独立构建要求：从空目录为工单 API 建立 Schema、结果联合、严格 tsconfig、非法夹具与 fail-fast verify；先注入断言绕过、忽略失败和脚本假通过，保存失败，再修复并重跑同一 oracle。

## 19. 版本表面与未验证边界

本章在 2026-07-17 对照 TypeScript 7.0.2、Zod 4.4.3、typescript-eslint flat config 与 Vitest 4.1.10 官方资料。稳定原则是外部数据从 unknown 开始、边界运行时校验、成功后类型收窄、失败稳定化、门禁 fail-fast；版本表面包括 Schema API、错误代码、TS 严格选项、lint presets 和工具最低 Node。

配套资产在本机 Node 22/pnpm 10 执行，不等于 canonical Node 24 LTS 证据。未验证真实 Java API、浏览器存储、生产环境变量、OpenAPI 生成链或 CI 平台；这些边界必须在对应集成环境重跑。

## 20. 官方资料

- [Zod 4：Basic usage](https://zod.dev/basics)
- [Zod 4：Error formatting](https://zod.dev/error-formatting)
- [Zod 4：Migration guide](https://zod.dev/v4/changelog)
- [TypeScript：strict](https://www.typescriptlang.org/tsconfig/strict.html)
- [TypeScript：TSConfig Reference](https://www.typescriptlang.org/tsconfig/)
- [TypeScript：Announcing TypeScript 7.0](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/)
- [typescript-eslint：Getting Started](https://typescript-eslint.io/getting-started/)
- [typescript-eslint：Typed Linting](https://typescript-eslint.io/getting-started/typed-linting/)
- [Vitest Guide](https://vitest.dev/guide/)

## 21. 本章结论

TypeScript 的可信范围止于编译器可证明的代码。网络、存储、配置和消息进入系统时必须先作为 unknown，用运行时 Schema 执行结构与约束检查；成功后通过 inferred type 进入受信任区域，失败则映射为稳定、脱敏的错误。严格 tsc、lint、format、测试和 build 各自覆盖不同风险，必须用 fail-fast 门禁组合。只有合法负载通过、缺失/额外/错误类型稳定失败且任一质量步骤都能阻断，边界才真正成立。
