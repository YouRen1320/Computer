---
schema_version: 2
edition: 2026.2-draft
id: ch.ts.modeling-narrowing
title: interface、type、联合、unknown、never 与收窄
responsibility: 用 interface/type、判别联合和控制流收窄表达业务状态与不可信输入，禁止用 any 跳过模型缺口。
volume: '08'
order: 16
level: L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.ts.modeling-narrowing.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ts.foundations
- ch.js.object-model
version_surfaces:
- typescript
- node-24-lts
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“interface、type、联合、unknown、never 与收窄”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - ts-modeling-unions
  - ts-unknown-narrowing
  covers_topics:
  - ts.interface
  - ts.type-alias
  - ts.union-intersection
  - ts.discriminated-union
  - ts.exhaustive-never
  - ts.unknown-any
  - ts.typeof-in-guard
  - ts.user-defined-type-guard
  - ts.control-flow-narrowing
  - js.prototype-chain
  uses_capabilities:
  - web.javascript-language
  - web.javascript-objects
  - web.typescript-types
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用判别联合建模工单加载状态并为 unknown API 数据实现运行时守卫；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - ts-modeling-unions
  - ts-unknown-narrowing
  covers_topics:
  - ts.interface
  - ts.type-alias
  - ts.union-intersection
  - ts.discriminated-union
  - ts.exhaustive-never
  - ts.unknown-any
  - ts.typeof-in-guard
  - ts.user-defined-type-guard
  - ts.control-flow-narrowing
  - js.prototype-chain
  uses_capabilities:
  - web.javascript-language
  - web.javascript-objects
  - web.typescript-types
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: tsc-noemit-exhaustiveness-fixture-runtime-guard-cases
- id: diagnose
  kind: fault-diagnosis
  text: 面对“any 逃逸、遗漏联合分支或错误 guard 导致的未处理状态”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ts-modeling-unions
  - ts-unknown-narrowing
  covers_topics:
  - ts.interface
  - ts.type-alias
  - ts.union-intersection
  - ts.discriminated-union
  - ts.exhaustive-never
  - ts.unknown-any
  - ts.typeof-in-guard
  - ts.user-defined-type-guard
  - ts.control-flow-narrowing
  - js.prototype-chain
  uses_capabilities:
  - web.javascript-language
  - web.javascript-objects
  - web.typescript-types
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# interface、type、联合、unknown、never 与收窄

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《类型标注、推断、数组、对象、元组与函数类型》](ch.ts.foundations.md)：接口、联合和收窄复用基础标注、推断与结构类型模型。
- [《this、原型、class 与对象模型》](ch.js.object-model.md)：运行时收窄必须基于真实对象属性、原型与身份边界，而不是只相信编译时形状。
<!-- END GENERATED LEARNING PREREQUISITES -->

TypeScript 能检查“源码怎样使用一个值”，却不会在网络响应到达时替你检查那份值。业务状态若只写成若干可选字段，加载、成功和失败可能被拼成互相矛盾的组合；外部数据若被直接断言成业务对象，检查器会基于一个未经证明的前提继续推理。本章把这两个问题连成一条证据链：先用 `interface`、`type` 和判别联合表达合法状态，再把边界输入保留为 `unknown`，依据 JavaScript 真正执行的检查逐步收窄，最后用 `never` 让新增状态在遗漏处理时产生编译证据。

本章的唯一职责是建模与收窄。它不教授第三方 Schema 库，不把类型声明说成运行时验证，也不以 `any`、宽泛断言或非空断言掩盖模型缺口。配套工件固定 TypeScript 编译器并保存三类证据：合法模型通过严格 `tsc --noEmit`；加入新变体而不处理时在 `never` 位置失败；真假 `unknown` 输入经过真实 guard 后分别进入成功与拒绝路径。这样，“代码看起来类型安全”会被替换为可复现的检查结果。

## 完成定义与 canonical 预言

完成本章必须同时满足以下条件：

1. 能在 120 秒内说明 `interface`、`type`、联合、交叉、判别字段、`unknown`、`any`、guard、控制流收窄和 `never` 的职责，并举出一个不应靠本章类型方案解决的反例。
2. 独立实现工单加载状态：空闲、加载中、成功和失败互斥；每个分支只暴露该状态可用的数据；渲染函数在默认分支把剩余值交给 `never`。
3. 把 API、`JSON.parse` 或消息边界的输入先视为 `unknown`，逐层验证对象性、自有属性、字段类型和业务允许值，然后才能构造领域对象。
4. 保存正证据：合法源码通过严格检查，合法与非法运行时样例得到确定输出。
5. 保存负证据：新增联合成员却遗漏分支时产生预期编译诊断；故意错误的 guard 或 `any` 逃逸在运行时暴露故障。
6. 修复后重跑原验证命令，而不是删除严格选项、扩大断言或换一个不覆盖故障文件的配置。

canonical T1 预言是：**所有状态分支被 `never` 穷尽，不可信值只有通过运行时 guard 后才能使用；新增变体会在预期编译点失败。**

这句话包含三个不同断言。穷尽性是编译期关系，guard 是运行时判定，新增变体负样例是在证明门禁确实会响。只运行成功路径不能证明新增状态被拦截；只看到编译通过也不能证明 guard 拒绝伪造数据；只写 `never` 却把输入先标为 `any`，同样没有边界证据。

## 从非法状态开始看模型问题

下面这个形状常见，却允许许多无意义组合：

~~~ts
interface LooseLoadState {
  loading: boolean;
  data?: WorkOrder;
  error?: string;
}
~~~

它允许 `loading: true` 同时带 `data` 和 `error`，也允许 `loading: false` 却两者皆无。调用者必须猜测字段优先级，并在每个消费点重复同一套判断。类型虽然列出了属性，却没有表达“哪些属性必须一起出现、哪些不能共存”。问题不是标注太少，而是模型没有把业务状态分开。

判别联合把每个合法状态写成独立成员：

~~~ts
interface IdleState {
  status: "idle";
}

interface LoadingState {
  status: "loading";
  requestId: string;
}

interface ReadyState {
  status: "ready";
  data: WorkOrder;
}

interface FailedState {
  status: "failed";
  message: string;
  retryable: boolean;
}

type WorkOrderLoadState = IdleState | LoadingState | ReadyState | FailedState;
~~~

共同的 `status` 字段使用互不重叠的字面量。检查 `state.status === "ready"` 后，TypeScript 能排除其余成员，于是 `state.data` 在该分支必然存在，而 `message` 不应该存在。模型从“字段可能出现”升级为“状态与字段之间存在可检查关系”。

## interface 与 type：先看职责，不背阵营

`interface` 擅长为对象形状命名，也支持扩展与声明合并；`type` 可以给任意类型表达式命名，包括联合、交叉、元组、基本类型联合和条件类型。两者描述对象时大量重叠，本章不建立“所有对象必须 interface”或“永远只用 type”的宗派规则。

一个清晰而非强制的团队约定是：稳定、可扩展的对象合同使用 `interface`；组合关系与有限状态使用 `type`。上例中的每个状态是对象合同，整体状态是联合，因此读者一眼能看到成员与组合。若项目公开 API 依赖声明合并，需要显式记录这种选择；若想阻止意外合并，也可统一使用类型别名。真正重要的是名字、责任和变更证据，而不是两个关键字的胜负。

不要把 `interface` 误解为运行时接口。编译输出里不会保留它，`value instanceof WorkOrder` 也不可能因为存在同名接口而工作。`instanceof` 需要右侧是运行时构造函数，并检查对象原型链；接口只有检查期意义。

## 联合表达“之一”，交叉表达“同时具备”

联合 `A | B` 表示值可以属于任一成员。在尚未收窄时，只能直接使用所有成员共同保证的操作。交叉 `A & B` 表示值同时满足两边形状，常用于给既有模型附加元数据：

~~~ts
interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
}

type Cached<T> = T & {
  cachedAt: number;
};

type CachedWorkOrder = Cached<WorkOrder>;
~~~

交叉不是对象合并函数，也不会在运行时复制字段。如果两个成员对同一属性提出互不相容的要求，结果可能把该属性压缩成 `never`，得到实际上无法构造的类型。遇到复杂交叉时，应先问领域里是否真的存在“同时属于两者”的值；若只是两种选择，应使用联合。

联合也不是自动的异或。两个结构成员若相互重叠，一个对象可能同时满足两者。判别联合之所以稳健，是因为每个成员有共同键且字面量互斥。不要仅靠“一个有 `data`，另一个有 `error`”猜分支，尤其当这些属性可选时；明确的 `status` 或 `kind` 会让模型和诊断更稳定。

## 判别联合与控制流

TypeScript 会沿着 `if`、`switch`、提前返回、赋值和可达性分析值的可能类型。这叫控制流收窄。一个渲染函数可以直接按状态分派：

~~~ts
function renderState(state: WorkOrderLoadState): string {
  switch (state.status) {
    case "idle":
      return "尚未请求";
    case "loading":
      return `正在加载 ${state.requestId}`;
    case "ready":
      return `${state.data.id}:${state.data.title}`;
    case "failed":
      return state.retryable ? `可重试：${state.message}` : state.message;
    default:
      return assertNever(state);
  }
}

function assertNever(value: never): never {
  throw new Error(`未处理状态：${JSON.stringify(value)}`);
}
~~~

每个 `case` 既是运行时分支，也是检查器的收窄证据。`default` 到达时，若前面覆盖了联合全部成员，`state` 会变为 `never`。如果未来加入 `CancelledState` 却没有新增 `case`，传给 `assertNever` 的值仍可能是取消状态，编译器便在这个集中位置报告不兼容。这比返回一个默认空字符串更可靠，因为默认值会吞掉业务新增状态。

显式返回类型也能帮助发现遗漏，但单靠它常只得到“函数可能返回 undefined”之类间接诊断。`never` 把错误定位在穷尽边界，并在诊断里显示剩余成员。负样例应断言诊断来自预期文件和错误类别，而不是只断言命令非零；否则语法错误或缺依赖也可能被误认为穷尽门禁有效。

## never 是不可到达，不是“什么都能装”

`never` 表示在当前分析下不可能产生值。永远抛错的函数可以返回 `never`，完全收窄后的剩余分支也是 `never`。它不同于 `void`：`void` 表示调用者不使用返回值，函数仍能正常结束；`never` 表示函数不会正常返回。

不要手工把普通值断言成 `never` 来让编译器安静：

~~~ts
// 反例：断言删除了新增状态的编译证据。
return assertNever(state as never);
~~~

这种写法让门禁失去意义。正确做法是让控制流自然证明剩余集合为空。若诊断出现，先检查是否真的遗漏分支，再检查判别字段是否被拓宽成普通 `string`、是否在收窄前复制或修改了值，以及函数是否接收了比预期更宽的类型。

## unknown 与 any：都是未知，权力完全不同

`unknown` 表示“当前没有足够证据知道如何使用”。任何值都能赋给 `unknown`，但在收窄之前不能读取属性、调用方法或当作具体业务类型传递。它迫使边界代码提出证据。`any` 则关闭大部分检查：可以读取任意属性、调用任意方法，也能污染后续推断。错误不会消失，只是从靠近输入的检查点移动到更晚的运行时位置。

~~~ts
function unsafe(value: any): string {
  return value.title.toUpperCase();
}

function honest(value: unknown): string {
  if (typeof value !== "string") {
    return "不是文本";
  }
  return value.toUpperCase();
}
~~~

`any` 在与其他类型组合时还会传播，代码补全与重构证据也会变弱。并非所有历史声明都能立刻消灭 `any`，但边界策略应是隔离和缩小：把第三方 `any` 立刻赋给 `unknown`，在一个小函数里验证，再把通过验证的领域值返回。不要让 `any` 穿过服务层进入组件、状态机或数据库写入。

## 从 unknown 开始的对象 guard

一个运行时对象 guard 必须先尊重 JavaScript 对象模型。`typeof value === "object"` 仍包含 `null`，数组也属于对象。读取属性前至少要排除 `null`；是否允许数组取决于协议。最小记录守卫可以写成：

~~~ts
function isRecord(value: unknown): value is Record<PropertyKey, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
~~~

随后验证每个必要字段：

~~~ts
function isWorkOrder(value: unknown): value is WorkOrder {
  if (!isRecord(value)) {
    return false;
  }

  return (
    typeof value.id === "string" &&
    value.id.length > 0 &&
    typeof value.title === "string" &&
    (value.priority === "low" || value.priority === "high")
  );
}
~~~

这段代码在运行时真的执行 `typeof`、长度和等值判断。返回类型中的 `value is WorkOrder` 是给检查器的承诺，函数体不会被自动证明等价于 `WorkOrder`。若作者只检查 `id` 却仍声明完整谓词，TypeScript 会在调用后相信错误承诺。因此 guard 自身必须有正负运行时测试：合法对象通过；缺字段、错字段、`null`、数组和原型继承伪装等样例按协议被接受或拒绝。

## typeof、等值与真值收窄

`typeof` 对基本值和函数最直接，但要记住 JavaScript 的真实结果。`typeof null` 是 `"object"`，数组也是对象，日期与普通记录同样是对象。检查 number 时还要决定是否允许 `NaN` 和无穷值；仅 `typeof value === "number"` 不表达有限整数。业务若要求重试次数，可追加 `Number.isInteger(value)` 与范围判断。

等值检查能把字面量联合缩小。对 `priority` 检查 `=== "low" || === "high"` 同时是运行时白名单和检查期收窄。对可缺失值，`value !== null && value !== undefined` 明确表达两种空值；团队若使用 `value != null` 同时排除二者，应记录这是有意利用宽松等值，而非拼写疏忽。

真值检查会同时排除空字符串、零、`false`、`null`、`undefined` 和 `NaN` 等假值。它适合“任何假值都算缺失”的合同，不适合零或空字符串是合法业务数据的情况。`if (count)` 不能区分零与缺失；`if (count !== undefined)` 才对应“存在即可”。收窄写法必须匹配业务语义，而不是选择最短字符数。

## in 运算符与原型链边界

`"id" in value` 在 JavaScript 中会沿原型链查找属性。TypeScript 可以据此收窄具有该必选或可选属性的联合成员，但运行时含义并非“JSON 自有字段存在”。如果协议要求数据包必须自己携带字段，应使用 `Object.hasOwn(value, "id")`，并在读取前确认是非空对象。

~~~ts
const inherited = Object.create({ id: "WO-PROTOTYPE" });
"id" in inherited;                 // true：原型链上存在
Object.hasOwn(inherited, "id");    // false：不是自有属性
~~~

这正是本章复用 `js.prototype-chain` 的地方。对于内存中的类实例，沿原型链查找方法可能是所需行为；对于解析后的 JSON 记录，自有属性白名单通常更符合协议。不能把 `in` 一概说成危险，也不能把它一概说成完整验证，必须写明数据来源和所有权要求。

`Object.hasOwn` 本身只证明键归对象所有，不证明值类型。检查顺序应是：确认非空对象；确认必要键的所有权（若协议要求）；读取后验证值；最后构造新的领域对象。复制经过验证的字段还能避免把未知附加字段与奇怪原型继续传入核心层。

## instanceof：运行时身份而非结构形状

`value instanceof Error` 会检查 `Error.prototype` 是否出现在值的原型链上，适合当前 realm 中的真实错误对象。它不验证接口，也可能跨 iframe、worker 或不同 JavaScript realm 失效，因为各 realm 的构造函数身份不同。网络 JSON 也不会在解析后自动成为某个类实例。

如果错误来自同一 Node 进程并保留原型，`instanceof Error` 可用于读取 `message`；若来自序列化边界，应按记录字段验证。若库会抛字符串、数字或任意值，`catch (error: unknown)` 后要先收窄，再生成展示文本。直接把 catch 变量标为 `any` 会重现边界逃逸。

## 用户定义谓词与断言函数

谓词函数返回布尔值，并通过 `value is Type` 告诉检查器 true 分支的类型。断言函数则以 `asserts value is Type` 表示：正常返回后条件成立，不成立时必须抛错或终止。

~~~ts
function assertWorkOrder(value: unknown): asserts value is WorkOrder {
  if (!isWorkOrder(value)) {
    throw new TypeError("invalid work order payload");
  }
}
~~~

两者选择取决于控制流合同。页面想展示“数据不可用”时，谓词或返回判别结果更容易组合；启动配置无效必须停止时，断言函数更直接。不要让名为 `assert...` 的函数失败后仍正常返回，也不要在谓词里吞掉所有错误并默认 true。

谓词是高信任代码。测试至少覆盖每个必要字段缺失、类型错误、允许枚举以外的值、`null`、数组和看似相似的对象。若 guard 递归验证数组，既要检查 `Array.isArray`，也要对每个元素应用元素 guard。仅检查第一个元素会让后续脏数据漏入。

## 先解析，再构造领域值

直接从未知记录返回原对象会保留额外属性和原型。更明确的模式是 guard 或解析函数通过后构造新值：

~~~ts
type ParseResult<T> =
  | { ok: true; value: T }
  | { ok: false; reason: string };

function parseWorkOrder(input: unknown): ParseResult<WorkOrder> {
  if (!isWorkOrder(input)) {
    return { ok: false, reason: "payload does not match WorkOrder" };
  }

  return {
    ok: true,
    value: {
      id: input.id,
      title: input.title,
      priority: input.priority
    }
  };
}
~~~

返回值本身也是判别联合，调用者检查 `result.ok` 后获得成功值或失败原因。这个设计把“输入是否可信”和“加载状态是什么”分成两层：解析结果描述单次转换；页面加载状态描述请求生命周期。不要把两者揉成几十个可选字段。

本章手写小 guard 是为了看清原理，不是鼓励大型协议永远手写。复杂嵌套数据、错误路径聚合、版本迁移和多处复用通常适合运行时 Schema 工具；那属于后续 `ch.ts.runtime-boundaries`。即使使用库，也仍要理解输入起点是 `unknown`、成功与失败如何建模，以及库推断类型和真实运行版本是否一致。

## 控制流收窄何时会失效

收窄不是给变量永久盖章。赋值可能改变值，闭包可能在稍后运行，别名可能修改同一对象。检查器会基于它能证明的控制流保守处理。

~~~ts
function scheduleTitle(order: { title?: string }): void {
  if (order.title === undefined) {
    return;
  }

  const title = order.title;
  queueMicrotask(() => {
    console.log(title.toUpperCase());
  });
}
~~~

这里把已收窄的基本值复制到局部常量，回调使用稳定快照。若回调直接再次读取 `order.title`，在它执行前另一个引用可能删除或改变属性，检查器未必保持收窄。是否需要快照还取决于业务：如果回调必须读取最新值，应在回调里重新检查，而非为了通过类型检查而复制旧值。

数组元素和可变对象也有相同问题。一次 guard 证明的是当时观察到的值；若后续把对象交给不受约束的代码，保证可能被破坏。`readonly` 能减少检查期修改面，却不是运行时深冻结，也不能约束 JavaScript 调用者。需要隔离时，构造新对象、限制可变别名并在真正边界重复验证。

## 可选链、非空断言与类型断言

可选链 `value?.field` 表示值缺失时结果为 `undefined`，它是运行时操作，也能反映到类型；它不会证明字段存在。非空断言 `value!` 只移除检查器眼中的 `null | undefined`，不增加运行时检查。类型断言 `value as WorkOrder` 同样不转换数据。

当代码出现断言时，审查者应问：证据来自哪里？若来自紧邻的运行时 guard，是否可以让控制流自然携带类型而无需断言？若来自 DOM 或框架无法表达的不变量，能否集中在一个小适配器并增加运行时失败信息？若回答只是“我知道 API 会这样返回”，那是未经保存的假设，不是证据。

断言并非绝对禁止。实现某些底层映射时，TypeScript 无法表达运行时循环保持的精确关系，可能需要局部断言。此时要把断言限制在实现内部，以泛型合同和正负测试包围；调用者不应被迫重复断言。本章的业务 guard 通常不需要这种逃生口。

## 一条可复现的边界流水线

推荐把外部输入处理分成可观察阶段：

    HTTP/JSON/消息产生未知值
              │
              ▼
        unknown 原始输入
              │  对象性、自有属性、字段与枚举检查
              ▼
       ParseResult<WorkOrder>
          │成功             │失败
          ▼                 ▼
    ReadyState         FailedState
          │                 │
          └──── 判别联合渲染 ┘
                    │
                    ▼
             never 穷尽门禁

每个箭头都有不同证据。JSON 解析成功只证明语法合法；guard 的运行测试证明选定样例被正确分类；TypeScript 证明通过分支后的源码按模型使用值；`never` 负样例证明新增成员会触发维护信号；界面或日志测试证明实际展示符合业务。不要用任一层替代全部层。

## 故障诊断：先找失败阶段

面对“未处理状态”时，先判断它在检查期还是运行期出现：

- `TS2322: Type 'CancelledState' is not assignable to type 'never'`：穷尽门禁工作正常，首个可信证据是联合新增成员但消费函数未新增分支。
- `Cannot read properties of undefined` 且 guard 声明通过：检查 guard 实现与负样例，谓词可能过度承诺。
- 变量在某处突然变成 `any`：从诊断位置逆向查看声明文件、JSON 包装器、断言和未标注回调，找到第一个失去类型信息的边界。
- `"id" in value` 接受原型字段：这是 JavaScript 原型链语义，不是 TypeScript 随机错误；根据协议改用自有属性检查。
- 检查器说对象可能为 `null`：确认是否只写了 `typeof value === "object"`，补上明确的非空检查。

修复时保留原失败命令和输入。对于新增状态，新增对应分支并重跑同一负样例基线；对于错误 guard，先添加能复现漏判的运行样例，再补齐检查；对于 `any`，把最靠近来源的位置改为 `unknown`，逐步恢复证据。不要只在崩溃行加 `?.`，那可能把错误数据悄悄变成 undefined 并继续传播。

## 常见失败模式

### 用一个大接口加许多可选字段表达状态

症状是每个调用点都有不同判断顺序。修复为互斥成员与明确判别字段，让非法组合无法构造。

### API 客户端直接返回 Promise<WorkOrder>

若客户端没有运行时解析，这个返回类型只是声明。更诚实的低层返回是 `Promise<unknown>`，或由经过测试的解析器返回 `ParseResult<WorkOrder>`。声明生成器也不能证明服务器实际响应符合规范。

### guard 只检查属性存在

`"id" in value` 不能证明 id 是非空字符串，也可能命中原型。继续检查所有权、值类型和业务集合。

### 用 default 分支返回占位字符串

它让新增状态静默进入占位路径。若联合应穷尽，默认分支接收 `never`；若数据可能来自未验证运行时，则先验证判别值，不能把 `never` 当运行时防火墙。

### 用 any 修复编译错误

这只移动故障。将来源隔离成 `unknown`，写最小 guard，并保存真、假输入证据。

### 把编译穷尽误当运行时穷尽

JavaScript 调用者或旧缓存仍可传入未知 `status`。在不可信边界先验证允许值；内部联合穷尽负责已验证模型的维护变更。

## 配套工件与验证顺序

本章有四个独立目录：

- `examples/encyclopedia/ch.ts.modeling-narrowing/`：完整展示状态联合、运行时 guard 与确定输出。
- `labs/encyclopedia/ch.ts.modeling-narrowing/`：绿色诊断实验，要求基线通过，并确认遗漏分支、错误 guard 与 `any` 逃逸各自以预期方式暴露。
- `exercises/encyclopedia/ch.ts.modeling-narrowing/`：公开红灯练习，故意加入取消状态却遗漏处理，验证器必须稳定失败。
- `solutions-private/encyclopedia/ch.ts.modeling-narrowing/`：私有绿色解答，同时补齐取消分支和未知输入验证。

建议按以下顺序工作：先读 README 的输入与预言；运行公开练习观察首个诊断；解释为什么它来自剩余联合成员；实现缺失分支与 guard；运行 `tsc --noEmit`；再运行正负输入；最后才对照私有解答。若直接复制答案，无法形成独立建模证据。

配套 `package.json` 将 TypeScript 固定为 `7.0.2`、包管理器声明为 `pnpm@11.11.0`、目标 Node 引擎声明为 `24.x`。本次机械验证主机实际是 Node `22.14.0`，因此能确认锁定编译器的静态诊断和该主机的命令行输出，不能宣称 Node 24、浏览器 realm、真实网络、打包器或跨 realm `instanceof` 已被验证。

## 120 秒 teach-back 模板

可以用下面结构口述：

1. `interface` 为对象合同命名，`type` 能为联合与交叉等组合命名；两者是检查期结构，不是运行时对象。
2. 判别联合用共同字面量字段把合法状态分开，控制流检查该字段后只暴露对应成员的数据。
3. `unknown` 接受任何输入但禁止无证据使用；`any` 关闭检查并传播风险。
4. `typeof`、等值、`in`、`instanceof` 与自定义 guard 都必须符合 JavaScript 的真实运行语义，尤其注意 null、数组、自有属性和原型链。
5. `never` 在完全收窄后表示没有剩余成员；新增成员而遗漏分支会在穷尽点产生编译证据。
6. 反例：类型系统不能证明某次真实 HTTP 响应可信，也不能替业务决定字段范围；需要运行时解析、测试和监控。

口述必须同时提到边界与证据。只定义术语不算完成；只说“TypeScript 很安全”也不算，因为安全范围取决于输入来源、编译配置、断言和运行时检查。

## 自检清单

- 是否用互斥联合成员替代了矛盾的可选字段组合？
- 判别字段是否是窄字面量，而不是普通 `string`？
- 每个消费位置是否按判别字段收窄，并在应穷尽处使用自然得到的 `never`？
- 外部值是否从 `unknown` 开始，而非未经证明的领域类型或 `any`？
- guard 是否真正检查对象、null、数组、必要字段、字段类型和允许集合？
- 使用 `in` 时是否明确需要原型链语义；协议要求自有属性时是否使用 `Object.hasOwn`？
- 谓词是否有能揭穿过度承诺的负运行样例？
- 回调或赋值之后是否仍错误依赖旧收窄；需要快照还是重新检查？
- 负编译样例是否确认了预期文件和诊断，而非仅检查非零退出？
- 是否区分 TypeScript 编译证据、Node 主机运行证据与未验证的浏览器/Node 24 边界？

## 有意不覆盖

本章不展开第三方 Schema 库、OpenAPI 代码生成、品牌类型、模板字面量类型、复杂泛型 guard 工厂、跨进程协议演进或安全沙箱。它也不保证手写 guard 足以应对大型攻击面。目标是建立可迁移的最小模型：非法状态尽量不可表达，不可信输入先保持未知，运行检查产生收窄证据，内部联合由 `never` 维护穷尽。运行时 Schema 与完整质量工具链由后续章节负责。

## 官方参考

资料复核日期为 2026-07-24。本次复核只确认下列官方页面仍直接描述本章使用的收窄、联合与 Node 版本表面；它不是 Node 24、浏览器或真实 HTTP 输入的运行验证。

- TypeScript Handbook, [Narrowing](https://www.typescriptlang.org/docs/handbook/2/narrowing.html)：控制流、`typeof`、真值、等值、`in`、谓词、判别联合与 `never`。
- TypeScript Handbook, [Everyday Types](https://www.typescriptlang.org/docs/handbook/2/everyday-types.html)：接口、类型别名、联合与断言的基础边界。
- Node.js, [Node.js Releases](https://nodejs.org/en/about/previous-releases)：Node 24 的官方 LTS 状态；版本状态不等于本地已完成该版本验证。
