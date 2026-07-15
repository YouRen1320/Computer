# 第 25 周：TypeScript 类型系统、泛型、收窄与运行时边界

## 定位

本周系统整理 TypeScript，而不是只复习接口写法。目标是能为 API、状态机、组件和错误建立精确类型，同时清楚类型在编译后会消失，网络响应、Storage 和用户输入必须运行时验证。

时间预算：15—18 小时。先在纯 TS 模块中建立类型，Week 26 再进入 Vue。

## 前置

- JavaScript 语言与浏览器异步/安全阶段通过；
- 能运行 `tsc --noEmit` 和测试；
- 能阅读 `tsconfig.json`、ESM import 和构建错误；
- FactoryCare OpenAPI/错误格式已有草案。

## 目标

- 理解结构类型、类型推断、宽化、字面量和 `as const`；
- 使用 union/intersection、discriminated union 和穷尽检查；
- 使用类型守卫、控制流收窄、`unknown`、`never`；
- 设计函数/对象/类/泛型/约束和常用 utility type；
- 区分 optional、`undefined`、`null` 和字段缺失；
- 理解 variance 的实用风险与函数参数检查；
- 配置严格 `tsconfig`，理解 declaration/source map/module resolution；
- 在 API 边界运行时验证并把未知数据转换为可信类型。

## 完整概念清单

### 类型推断与基本建模

- annotation、inference、contextual typing；
- literal widening、`const`、`as const`、`satisfies`；
- primitive、array、tuple、object、readonly；
- interface 与 type alias 的共同点、扩展/合并差异；
- structural typing 与 excess property check；
- index signature、Record 和动态 key；
- enum 与 string union 的取舍；
- 不用 wrapper object 类型 `String/Number/Boolean`。

### 联合、交叉与收窄

- union 表示“之一”，intersection 表示同时满足；
- discriminant 设计和 `switch` 穷尽；
- `typeof`、`in`、`instanceof`、equality narrowing；
- user-defined type predicate/assertion function；
- truthiness narrowing 可能误删 0/空字符串；
- `never` 做穷尽检查，`unknown` 迫使验证；
- `any` 关闭检查，应限制在迁移边界并尽快收窄；
- type assertion 不做运行时转换，双重断言是危险逃逸。

### 函数与泛型

- function type、call signature、optional/default/rest 参数；
- overload signature 与 implementation signature；优先 union/泛型表达清晰关系；
- generic function/type/interface/class；
- constraint、`keyof`、indexed access、`typeof` type query；
- generic default 和合理类型参数数量；
- 泛型应表达输入输出关系，不用 `<T>` 装饰任何函数；
- covariance/contravariance/invariance 的直觉和可变容器风险；
- callback 参数与 `strictFunctionTypes`。

### 高级类型与工具

- `Partial/Required/Readonly/Pick/Omit/Record/Exclude/Extract/NonNullable/ReturnType/Parameters`；
- mapped type、key remapping、conditional type、`infer` 的可读范围；
- template literal type 适合有限协议，不模拟任意字符串解析器；
- branded/opaque ID 类型模拟值对象，但运行时仍是原值；
- recursive type 与编译性能；
- 不追求晦涩类型体操，API 可读性优先。

### null、可选与错误

- `strictNullChecks`；
- `x?: T` 与 `x: T | undefined` 在写入/存在性上的差异；
- JSON 中 `null` 与字段缺失；
- optional chaining 和 `??`；
- catch variable 为 `unknown`，先判断再读取；
- Result/discriminated union 与 throw 的适用边界；
- 非空断言 `!` 只在外部不变量已由证据保证时使用。

### 编译配置与运行时验证

- TypeScript 做静态检查并输出 JS，不提供运行时类型；
- strict、noImplicitOverride、noUncheckedIndexedAccess、exactOptionalPropertyTypes 等策略；
- target、module、moduleResolution、lib、types、paths；
- `isolatedModules`、declaration、sourceMap、incremental；
- 浏览器/Node 类型环境不要无边界混合；
- API/Storage/postMessage/URL 参数用 schema 或手写 validator 验证；
- OpenAPI 生成类型减少漂移，但业务包装和 CI 契约检查仍需要。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 推断/结构/严格配置 | 2—3h | strict 工程和错误对照 |
| union/收窄/never | 3h | 状态机和错误模型 |
| 泛型/utility | 3h | 分页、仓储、表格列类型 |
| null/unknown/运行时验证 | 2—3h | 不可信 API 解析器和失败用例 |
| OpenAPI/边界 | 2h | 生成 DTO 与手写领域类型映射 |
| FactoryCare/复盘 | 3—4h | 类型包、故障和独立变更 |

## FactoryCare 增量

- 定义 `WorkOrderSummary`、分页响应、稳定错误码和 12 状态 union；
- 用 discriminated union 表达 loading/empty/error/success；
- 用 branded ID 防止 DeviceId/WorkOrderId 静态混用；
- 实现 `parseWorkOrderResponse(value: unknown)` 或 schema 验证；
- 用 `never` 保证状态映射穷尽；
- 开启严格配置，禁止生产代码 `any`/无依据 `!`/双重断言；
- 证明伪造 `as WorkOrder` 可通过编译但在运行时失败。

## 无 AI 任务（120 分钟）

给定一份故意不稳定的 API JSON，设计 `unknown → Result<WorkOrder, ValidationError[]>` 转换：验证 ID、状态、时间、可选字段和嵌套技师；错误包含路径和原因。再实现一个泛型分页映射器并覆盖空页、非法状态和缺字段。

## 验收

- 能解释 `any`、`unknown`、`never` 和 assertion 的边界；
- 能设计 discriminated union 并做穷尽检查；
- 能说明泛型表达的输入输出关系，而不是只会写 `<T>`；
- strict `tsc --noEmit`、测试和构建通过；
- 网络响应未经验证不能进入可信领域类型；
- 能独立增加一个 API 字段并更新 schema、类型、映射和测试。

## 非目标

- 不做类型体操竞赛；
- 不进入 Vue 类型宏，留到 Week 26；
- 不把 OpenAPI 生成物当业务领域模型；
- 不用断言消灭所有编译错误。
