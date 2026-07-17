---
schema_version: 2
edition: 2026.2-draft
id: ch.ts.generics-utilities
title: 泛型、约束、工具类型、映射与条件类型
responsibility: 用泛型约束表达跨类型关系，并在有明确收益时使用工具、映射和条件类型，不追求难以诊断的类型体操。
volume: '08'
order: 17
level: L2+
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.ts.generics-utilities.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ts.modeling-narrowing
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
  text: 在 120 秒内解释“泛型、约束、工具类型、映射与条件类型”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - ts-generics-constraints
  - ts-utility-mapped-conditional
  covers_topics:
  - ts.generic-parameter
  - ts.generic-constraint
  - ts.keyof-indexed-access
  - ts.generic-inference
  - ts.utility-types
  - ts.mapped-type
  - ts.conditional-type
  - ts.infer-keyword
  - ts.type-complexity-budget
  uses_capabilities:
  - web.typescript-types
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现类型安全的字段选择与补丁工具并对复杂度设定可审查上限；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - ts-generics-constraints
  - ts-utility-mapped-conditional
  covers_topics:
  - ts.generic-parameter
  - ts.generic-constraint
  - ts.keyof-indexed-access
  - ts.generic-inference
  - ts.utility-types
  - ts.mapped-type
  - ts.conditional-type
  - ts.infer-keyword
  - ts.type-complexity-budget
  uses_capabilities:
  - web.typescript-types
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: tsc-type-fixture-positive-negative-cases-type-simplification-review
- id: diagnose
  kind: fault-diagnosis
  text: 面对“无约束泛型、分布式条件类型或过度断言造成的类型失真”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ts-generics-constraints
  - ts-utility-mapped-conditional
  covers_topics:
  - ts.generic-parameter
  - ts.generic-constraint
  - ts.keyof-indexed-access
  - ts.generic-inference
  - ts.utility-types
  - ts.mapped-type
  - ts.conditional-type
  - ts.infer-keyword
  - ts.type-complexity-budget
  uses_capabilities:
  - web.typescript-types
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 泛型、约束、工具类型、映射与条件类型

泛型的价值不是“让一个函数接受所有东西”，而是保存输入之间、输入与输出之间的关系。一个 `any` 函数也能接受所有东西，却会丢失键名、字段值和返回结果之间的联系。一个设计良好的泛型 API 则让调用者传入工单和字段列表后，返回值只暴露被选字段；传入不存在的键会在调用点失败；补丁允许修改的字段由模型推导，而不是复制一份容易漂移的字符串名单。

本章从具体工具出发：类型安全字段选择与补丁。由此引入泛型参数、约束、推断、`keyof`、索引访问、内置工具类型、映射类型、条件类型和 `infer`。每增加一层类型表达，都必须回答它保存了什么业务关系、错误是否更靠近调用点、运行时是否仍有对应实现、团队是否能读懂诊断。若答案不清楚，就优先使用较简单的显式类型或函数重载，而不是追求类型体操。

## 完成定义与 canonical 预言

完成本章必须交出以下证据：

1. 在 120 秒内解释泛型参数与约束、`keyof` 与索引访问、推断、常用工具类型、映射类型、条件类型、`infer` 和复杂度预算，并给出一个不应由高级类型解决的反例。
2. 实现 `selectFields`：调用者传入对象和合法键集合，返回类型精确保留所选字段；不存在的键在预期调用点产生编译诊断。
3. 实现补丁模型：不可修改的标识字段被排除，其余字段按需要变为可选；运行时应用补丁的行为明确且有输出预言。
4. 保存正负类型样例：合法选择与补丁通过；非法键、缺少约束、错误分布式条件结果在各自文件以预期诊断失败。
5. 保存类型简化审查：说明为什么当前工具值得存在、公开类型别名有几层、是否能用内置工具或显式联合替代。
6. 注入过度断言造成的类型失真，定位编译期承诺和运行时值分离的第一处证据，修复后重跑同一验证。

canonical T1 预言是：**泛型 API 保持输入输出关系，非法键和不满足约束的类型在预期位置失败，简化前后运行时行为不变。**

这包含静态与动态两部分。类型样例证明调用合同，运行输出证明 JavaScript 实现；简化审查证明类型成本受到约束。只展示编辑器悬停不够可复现，只运行成功值不能证明非法键被拒绝，只写复杂条件类型但没有调用者收益也不满足本章职责。

## 从重复函数到关系参数

假设先有两个函数：

~~~ts
function firstWorkOrder(items: WorkOrder[]): WorkOrder | undefined {
  return items[0];
}

function firstTechnician(items: Technician[]): Technician | undefined {
  return items[0];
}
~~~

两者运行逻辑完全相同，区别只是元素类型。泛型把这个变化点提取为类型参数：

~~~ts
function first<T>(items: readonly T[]): T | undefined {
  return items[0];
}
~~~

`T` 不是运行时变量，也不是“任意类型”的同义词。每次调用会为它确定一个具体类型，返回值与数组元素保持同一关系。传入 `WorkOrder[]` 得到 `WorkOrder | undefined`，传入 `Technician[]` 得到 `Technician | undefined`。若改成 `unknown[] -> unknown`，调用者必须重新收窄；若改成 `any[] -> any`，关系和检查都丢失。

是否需要泛型取决于参数出现方式。一个类型参数若只出现一次，常常没有建立关系：

~~~ts
function logValue<T>(value: T): void {
  console.log(value);
}
~~~

这里 `unknown` 往往足够，因为函数不返回 T，也没有第二个位置需要与它一致。泛型参数至少应连接两个可观察位置，或用于约束成员操作。不要仅为让签名显得高级而加 `<T>`。

## 泛型约束：声明实现真正需要的能力

未约束的 `T` 可能是字符串、数字、函数、null 或对象，因此实现不能直接读取 `.id`。如果函数确实需要 id，就用约束表达最小能力：

~~~ts
function indexById<T extends { readonly id: PropertyKey }>(
  items: readonly T[]
): Map<T["id"], T> {
  return new Map(items.map((item) => [item.id, item]));
}
~~~

`extends` 在这里表示可赋值约束，不是类继承。调用值可以有更多字段，只要至少有合法 id。返回 Map 的键类型还通过 `T["id"]` 保留输入模型的实际 id 类型；如果只写 `Map<PropertyKey, T>`，虽然实现合法，却丢失了字符串字面量或数字键关系。

约束应尽可能小但真实。要求完整 `WorkOrder` 会排斥本来可用的其他实体；只约束 `{}` 又无法证明 `.id` 存在。不要用 `T extends any`，它几乎不提供能力证据。`T extends object` 排除基本值，但仍不证明具体属性。先列出函数体读取的成员，再从中形成约束。

## keyof：从对象类型得到键集合

对对象类型 `T` 使用 `keyof T`，会得到已知属性键的联合。例如：

~~~ts
interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
  completed: boolean;
}

type WorkOrderKey = keyof WorkOrder;
// "id" | "title" | "priority" | "completed"
~~~

它是检查期集合，不会在运行时生成数组。要真正枚举对象仍需 `Object.keys`、显式键列表或其他 JavaScript 操作。`Object.keys` 返回字符串数组，是因为运行时对象可能有额外字段，类型也未必是封闭精确形状。不要无条件把 `Object.keys(value)` 断言成 `(keyof T)[]` 后声称安全；该断言需要更强的对象所有权与构造前提。

索引签名会影响 `keyof`。若类型允许任意字符串键，键集合会拓宽为 `string` 或 `string | number`，非法拼写门禁便不再窄。字段选择 API 若依赖有限键，输入模型应有明确属性，而不是宽泛的 `[key: string]: unknown`。

## 索引访问：让键决定值类型

`T[K]` 表示类型 T 在键 K 处的值类型。结合约束，可以写出安全取值：

~~~ts
function getField<T, K extends keyof T>(object: T, key: K): T[K] {
  return object[key];
}
~~~

调用 `getField(order, "priority")` 时，K 推断为 `"priority"`，返回值是 `"low" | "high"`；传入 `"missing"` 会在参数位置失败。这里的两个类型参数保存了对象、键和值三者的关系。

如果签名写成 `(object: object, key: string): unknown`，实现可能仍能运行，却把关系推给每个调用者重复恢复；若写成返回 `any`，还会隐藏错误。若函数允许动态用户输入的字符串，不能仅靠 `keyof`，因为运行时字符串不一定属于键集合；需要先做运行时成员白名单检查，再进入泛型内部。

数组和元组也支持索引访问。`T[number]` 常用于从只读数组或元组取得元素联合：

~~~ts
const priorities = ["low", "high"] as const;
type Priority = (typeof priorities)[number];
~~~

这里 `typeof priorities` 是类型查询，`[number]` 取所有数字索引位置的值联合。运行时数组仍只是数组，`as const` 也不会冻结它；如果外部输入要限制为这些值，仍需等值或集合检查。

## 类型安全字段选择

字段选择需要同时保存键列表和返回对象形状：

~~~ts
function selectFields<
  T extends object,
  const K extends readonly (keyof T)[]
>(object: T, keys: K): Pick<T, K[number]> {
  const selected: Partial<Pick<T, K[number]>> = {};

  for (const key of keys) {
    selected[key] = object[key];
  }

  return selected as Pick<T, K[number]>;
}
~~~

`K` 保存整组键的元组信息，`K[number]` 得到所选键联合，`Pick` 构造返回形状。`const` 类型参数帮助调用字面量保持较窄推断。实现末尾有一个局部断言，因为 TypeScript 不会完整证明循环已经给 `selected` 写入 K 的每个成员。这个断言被限制在工具内部，并由非法键编译样例与精确运行输出包围；调用者不需要断言。

局部断言必须审查运行时实现。若循环跳过某个键、重命名字段或从另一个对象读取，返回合同就会失真。不能因为签名漂亮就忽略实现测试。也可以用 `Object.fromEntries` 构造，再做一次局部断言；它没有消除证明义务，只改变了实现。

## 泛型推断：让调用点提供证据

TypeScript 会从实参、上下文返回位置和默认类型参数推断候选。通常应让调用者写 `selectFields(order, ["id", "priority"])`，而不是要求 `selectFields<WorkOrder, ...>` 手工列出所有参数。冗余显式参数容易与实参漂移，也会掩盖推断设计问题。

推断结果受字面量是否拓宽影响：

~~~ts
const keys = ["id", "priority"];
// keys 常被推断为 string[]，已丢失有限键信息。

const stableKeys = ["id", "priority"] as const;
// readonly ["id", "priority"]，可保留精确联合。
~~~

现代 TypeScript 的 const 类型参数能在某些内联调用处保留窄信息，但变量在进入函数前已经拓宽时，函数无法神奇恢复原字面量。可以使用 `as const`，或用 `satisfies readonly (keyof WorkOrder)[]` 检查键列表同时保留推断。选择哪种写法应以目标 TypeScript 版本的实际诊断为准。

不要通过给返回值加断言来“修复推断”。先检查参数位置是否足以推导关系、是否用了过宽注解、是否需要另一个类型参数，以及 API 是否把太多任务塞进一个函数。重载有时比复杂条件返回更清晰。

## 内置工具类型：复用常见变换

TypeScript 全局提供多种常见类型变换：

- `Partial<T>`：把 T 的属性变为可选，适合补丁草稿，不代表运行时对象自动补全。
- `Required<T>`：把可选属性变为必选，适合“完成归一化后”的内部形状，但需要对应运行实现。
- `Readonly<T>`：阻止通过该类型重新赋值第一层属性，不是运行时冻结，也不是默认深只读。
- `Pick<T, K>`：选择键 K。
- `Omit<T, K>`：排除键 K。
- `Record<K, V>`：为键集合 K 建立同一值类型的映射。
- `Exclude<U, M>` 与 `Extract<U, M>`：从联合中排除或保留可赋值成员。
- `NonNullable<T>`：排除 null 与 undefined。
- `Parameters<F>`、`ReturnType<F>`：从函数类型提取参数元组与返回值。
- `Awaited<T>`：按 await 语义递归展开 Promise-like 结果。

工具类型只在检查期转换类型，不会修改对象。`Readonly<WorkOrder>` 不会调用 `Object.freeze`，`Required<Config>` 不会生成缺失默认值，`Omit<WorkOrder, "id">` 不会从运行对象删除 id。若运行时行为需要对应变换，必须实现并测试。

工具类型也不是业务语义的替代品。`Partial<WorkOrder>` 允许 id 被修改，可能不符合补丁合同。更合理的定义是：

~~~ts
type WorkOrderPatch = Partial<Omit<WorkOrder, "id">>;
~~~

若某字段必须随另一字段一起出现，简单 `Partial` 仍过宽，应使用判别联合或专门命令类型。先建模合法业务状态，再选择工具类型；不要从方便的 `Partial` 反推业务规则。

## 映射类型：逐键转换属性

映射类型遍历 `keyof` 联合并为每个键生成属性：

~~~ts
type FieldErrors<T> = {
  [K in keyof T]?: string;
};
~~~

这与 `Partial<Record<keyof T, string>>` 近似，前者更容易继续依据 `T[K]` 做条件映射。映射修饰符可以增加或移除可选、只读属性：`+?`、`-?`、`+readonly`、`-readonly`。除非移除行为是核心，否则通常省略加号。

键重映射使用 `as`：

~~~ts
type ChangeHandlers<T> = {
  [K in keyof T as `on${Capitalize<string & K>}Change`]?:
    (value: T[K]) => void;
};
~~~

它能从模型生成事件处理器名，但诊断和编辑器悬停会变长。若字段只有三项且公开 API 稳定，显式接口可能更容易发现命名变化。映射类型适合稳定、机械的一一关系，不适合隐藏复杂业务分支。

## 条件类型：在类型层表达分支关系

条件类型形如 `T extends U ? X : Y`，依据可赋值关系选择结果：

~~~ts
type ApiResult<T> = T extends Error
  ? { ok: false; error: T }
  : { ok: true; value: T };
~~~

它不是运行时 `if`，不会检查某个真实值。若函数返回结果联合，JavaScript 实现仍要在运行时构造正确的 `ok` 分支。条件类型适合描述既有 API 的类型关系，不应凭空宣称运行时转换已经发生。

条件类型常与泛型一起延迟求值。对于具体类型，结果可直接化简；对于未确定 T，检查器保留条件。过多嵌套会让诊断显示长串未化简表达，因此应给重要中间结果命名并限制公开层数。

## 分布式条件类型：联合会逐成员计算

当条件左侧是裸类型参数 `T` 时，传入联合会对每个成员分配计算：

~~~ts
type ToArray<T> = T extends unknown ? T[] : never;
type Result = ToArray<string | number>;
// string[] | number[]，不是 (string | number)[]
~~~

分布可能正是所需，例如从事件联合筛选某个成员；也可能造成类型失真。若要把联合整体测试，使用元组包裹两边：

~~~ts
type ToArrayWhole<T> = [T] extends [unknown] ? T[] : never;
type Whole = ToArrayWhole<string | number>;
// (string | number)[]
~~~

诊断分布问题时，先把 T 替换为最小联合，手工展开每个成员，再判断业务需要“逐成员”还是“整体”。不要随机添加 `& {}`、双重条件或断言直到错误消失。配套实验用类型相等断言保存这一差异，确保负样例因预期结果不一致而失败。

## infer：在条件匹配中命名一部分类型

`infer` 只能在条件类型的 true 分支匹配位置引入临时类型变量。例如提取 Promise 结果：

~~~ts
type UnwrapPromise<T> = T extends Promise<infer Value> ? Value : T;
~~~

或提取函数第一个参数：

~~~ts
type FirstParameter<T> =
  T extends (first: infer P, ...rest: never[]) => unknown ? P : never;
~~~

在真实代码里，先检查是否已有 `Awaited`、`Parameters`、`ReturnType` 等内置工具。重复实现标准工具增加维护成本，也可能遗漏 Promise-like、重载或特殊边界。学习 `infer` 的目的，是能读懂库声明并在确有独特关系时表达，而不是建立私人标准库。

对重载函数提取类型时可能得到最后一个签名的结果，而不是依据某次调用做重载解析。若精确调用关系重要，直接为 API 写清重载或调整设计，不要假设 `ReturnType` 能模拟所有调用选择。

## 补丁工具：从业务不变量开始

工单补丁不应允许修改 id，也不一定允许所有字段都缺席。最小可审查版本可以是：

~~~ts
type Patch<T, Locked extends keyof T> = Partial<Omit<T, Locked>>;

function applyPatch<T extends object, Locked extends keyof T>(
  current: T,
  patch: Patch<T, Locked>
): T {
  return { ...current, ...patch };
}
~~~

这个泛型签名有一个陷阱：`Locked` 只出现在 patch 类型里，调用推断未必能从空补丁得到期望锁定键。对单一领域 API，直接定义 `WorkOrderPatch` 和 `applyWorkOrderPatch` 往往更清楚。泛化只有在多个模型共享相同锁定策略并且调用体验经过样例证明时才值得。

此外，对象展开是浅合并，嵌套对象会整体替换；undefined 是否允许写入受 `exactOptionalPropertyTypes` 和字段合同影响；只读是检查期视角，展开会创建新对象但不深复制。类型不能替代这些运行语义的测试。

配套工件选择显式 `WorkOrderPatch = Partial<Omit<WorkOrder, "id">>`，再把泛型集中在字段选择工具。这是一项有意的复杂度控制：不是所有可泛化位置都必须泛化。

## 事件联合与映射：一个有收益的高级例子

若系统已有判别事件联合，可以从事件 `type` 生成处理器表：

~~~ts
type WorkOrderEvent =
  | { type: "created"; order: WorkOrder }
  | { type: "priorityChanged"; id: string; priority: WorkOrder["priority"] };

type Handlers<E extends { type: PropertyKey }> = {
  [K in E["type"]]: (event: Extract<E, { type: K }>) => void;
};
~~~

这里映射类型遍历判别值，`Extract` 为每个键选择对应成员。收益是新增事件会要求处理器表新增键，而且每个回调获得精确成员。成本是类型表达有两层操作；如果团队不熟悉，应通过命名、示例和负样例降低认知负担。

运行时分派仍需实现，并要考虑来自外部的未知 type。内部经过验证的事件可以索引处理器；外部消息必须先解析。不要把 `Handlers` 当成消息验证器。本章前置的判别联合与 unknown 收窄正是这条边界。

## 类型复杂度预算

“能编译”不是高级类型的完成标准。一个可审查预算可以包含：

1. 每个公开类型别名尽量只组合一到两种主要操作；超过时拆成有领域名字的中间类型。
2. 条件类型嵌套不超过两层；递归类型必须有明确终止、真实样例和编译性能理由。
3. 优先内置工具类型，避免重复实现 `Partial`、`Awaited` 或 `ReturnType`。
4. 公开 API 至少保存一个合法调用和一个非法调用 fixture；错误应落在调用点，而不是库实现深处。
5. 每个断言记录无法由检查器表达的不变量，并由运行时测试覆盖；禁止把断言扩散给调用者。
6. 类型检查耗时若明显增长，用编译诊断工具测量；不要凭感觉归因。
7. 若显式接口或两个重载更易懂，允许放弃泛型抽象。

预算不是语言硬限制，而是团队维护策略。本章配套 `complexity-review.md` 会记录选择、替代方案、公开操作层数和断言边界，验证器只机械确认审查存在；审查内容仍需人判断。

## 何时选择重载、联合或普通函数

泛型适合连续关系：输入某个 T，输出仍与同一 T 或其键有关。重载适合少量离散调用形态，尤其运行时也有清楚分支。联合适合参数可以是几种已知形状，而输出不需要精确随每个成员变化。普通具体函数适合单一领域操作。

例如 `format(value: string | number): string` 不需要泛型，因为返回始终字符串；`parse(kind: "order" | "user")` 若想按字面量返回不同类型，可用重载或泛型映射，但只有两个稳定分支时重载诊断可能更清楚；`selectFields` 的键集合连续变化，泛型是自然选择。

设计评审不要只比较签名长度，还要比较调用点提示、错误位置、实现断言、扩展成本和团队熟悉度。最短的声明不一定最可维护，最抽象的声明也不一定复用最多。

## 过度断言如何制造类型失真

下面签名看似精确，运行实现却没有依据键列表：

~~~ts
function brokenSelect<T, K extends keyof T>(
  object: T,
  keys: readonly K[]
): Pick<T, K> {
  return { wrong: true } as Pick<T, K>;
}
~~~

编译器会相信断言，调用者读取 `result.id` 时得到 string 类型，但运行值没有 id。首个可信证据不是调用者崩溃那一行，而是工具实现用无关对象断言为 `Pick<T, K>`。修复应让循环真正复制每个键，再用最小局部断言封闭检查器无法证明的初始化过程，并添加精确输出测试。

双重断言 `value as unknown as Target` 更危险，因为它明确绕过可赋值关系。若底层适配确实需要，应缩小到一行、添加原因和契约测试；业务工具通常没有理由使用。不要把“TypeScript 允许断言”误说成“转换是安全的”。

## 故障诊断：三类首个可信证据

### 无约束泛型

诊断如 `Property 'id' does not exist on type 'T'`，说明实现使用了签名没有声明的能力。修复为真实最小约束，或停止访问该成员。不要把参数改成 `any`。

### 非法键未被拒绝

检查键参数是否是 `string`、模型是否有宽索引签名、键数组是否在调用前拓宽，以及返回是否被断言。目标诊断应落在非法键实参处。若只在运行时得到 undefined，泛型关系没有建立或被逃逸破坏。

### 分布式条件类型结果意外

把联合逐成员展开，判断业务要整体还是分配。需要整体时用 `[T] extends [U]`；需要分配时保留裸参数并为中间结果命名。不要用断言抹去类型差异。

### 过度断言

如果静态类型说字段存在但运行输出缺失，搜索 `as`、双重断言、`Object.keys` 转键和不安全泛型实现。记录最早让编译器相信错误形状的位置，而不是只修消费点。

修复后必须重跑原来的正负样例和运行预言。若简化高级类型，还要确认运行 JavaScript 未改变；通常纯类型别名会被擦除，但函数签名简化可能伴随实现重构，不能凭“类型不运行”跳过测试。

## 正负类型 fixture 的设计

正样例应证明推断结果，而不只是“没有错误”。可以通过赋值到预期形状、调用只存在于正确值类型的方法，或使用小型类型相等工具。负样例应独立文件，故意传非法键或不满足约束的类型，并由验证器确认文件名与诊断代码。

不建议把所有负样例长期写成 `@ts-expect-error` 混在生产源码。它适合类型测试，但若错误原因变化，只确认“此行有某个错误”可能不够精确。独立 fixture 配合捕获编译输出更适合教学诊断：学习者能看到原始 TS 诊断，绿色基线也不会被故意错误污染。

类型相等工具本身也有复杂度，应局限于测试：

~~~ts
type Equal<A, B> =
  (<T>() => T extends A ? 1 : 2) extends
  (<T>() => T extends B ? 1 : 2) ? true : false;

type Expect<T extends true> = T;
~~~

业务代码不需要理解它；测试用它确认 `Select` 或非分布结果。若工具对特殊类型如 `any`、never 或交叉归一化表现不直观，应承认边界，不把它当形式证明系统。

## 运行时不变量仍要独立验证

类型会被擦除。`selectFields` 必须真的只复制指定键，`applyPatch` 必须保留 id，事件分派必须调用对应处理器。即便类型 fixture 全绿，循环写错、键顺序、对象展开覆盖顺序或副作用仍可能错误。

外部字符串也不会因为参数最终要求 `keyof T` 就自动合法。若用户通过 URL 查询选择字段，先用运行时集合验证每个字符串，再调用内部选择器。若用强制断言把字符串数组变成键数组，非法键会在结果中产生 undefined 或遗漏字段。

本章运行样例使用内联可信键元组和领域对象，目的在验证映射实现，不代表网络边界已验证。真实 API、浏览器表单、数据库数据和 Node 24 运行仍需各自证据。

## 配套工件

四个独立目录分别承担不同证据：

- `examples/encyclopedia/ch.ts.generics-utilities/`：字段选择、不可改 id 的补丁和条件展开示例，严格检查后比较运行输出。
- `labs/encyclopedia/ch.ts.generics-utilities/`：绿色基线加四个故障注入：非法键、无约束泛型、错误分布预期与过度断言运行失真；同时检查复杂度审查记录。
- `exercises/encyclopedia/ch.ts.generics-utilities/`：公开红灯练习，键参数暂为普通 string，导致 TS7053；修复后仍要通过非法键负 fixture 与运行输出。
- `solutions-private/encyclopedia/ch.ts.generics-utilities/`：私有绿色解答，用 `K extends keyof T` 和 `Pick<T, K>` 保存关系，并保持补丁实现具体可读。

所有工件将 TypeScript 固定为 `7.0.2`，包管理器声明为 `pnpm@11.11.0`，Node 引擎声明为 `24.x`。机械验证主机是 Node `22.14.0`；因此结果能证明锁定 TypeScript 的诊断以及该主机执行的 JavaScript 输出，不能证明 Node 24、浏览器、打包器、声明发布、编辑器性能或真实外部输入。

## 120 秒 teach-back 模板

可以这样组织口述：

1. 泛型参数用于连接多个类型位置，约束声明实现所需最小能力；`any` 接受所有值却破坏关系。
2. `keyof T` 得到已知键联合，`T[K]` 让键决定值；`K extends keyof T` 把非法键挡在调用点。
3. 推断从实参与上下文选择类型参数，字面量拓宽会丢失精确键信息。
4. `Pick`、`Omit`、`Partial` 等工具类型复用常见变换，但不执行运行时复制、删除、默认值或冻结。
5. 映射类型逐键生成属性，条件类型按可赋值关系选择；裸类型参数遇联合会分布，元组包裹可改为整体判断。
6. `infer` 在条件匹配中提取部分类型，先优先使用标准工具。
7. 复杂度预算限制嵌套、断言和公开操作层数；反例是外部字段名验证与业务授权，它们不能由泛型自动解决。

必须补充证据：合法与非法 fixture、固定编译器诊断、运行输出和简化审查。只会写 `Partial` 定义不等于能设计可维护泛型 API。

## 自检清单

- 每个泛型参数是否连接至少两个位置，或提供实现真正需要的能力？
- 约束是否最小且真实，避免 `extends any` 或过宽 object 掩盖成员需求？
- 非法键是否在调用点失败，返回值是否精确为所选字段？
- 键数组是否因普通变量声明拓宽成 string[]？
- 是否优先使用内置工具，而非复制标准实现？
- `Partial`、`Omit` 和 `Readonly` 是否符合业务不变量，而非仅为方便？
- 条件类型面对联合时，是否明确需要分布还是整体判断？
- `infer` 是否提取真实关系，是否已有 `Awaited`、`Parameters` 或 `ReturnType`？
- 断言是否限制在实现内部并由运行测试包围？
- 公开类型是否在复杂度预算内，错误信息是否能由团队解释？
- 类型简化前后是否重跑相同运行预言？
- 是否区分锁定编译器证据与未验证的 Node 24、浏览器和真实输入？

## 有意不覆盖

本章不教授递归模板字面量解析器、任意深度路径类型、品牌类型框架、方差标注、声明文件发布兼容、编译器性能剖析全流程或类型挑战题。它也不把泛型用于运行时授权、数据校验或数据库事务。目标是建立可维护的中阶工具：用约束保存真实关系，用标准工具和一层映射/条件表达机械变换，以正负 fixture 和运行预言约束局部断言，并在复杂度超过收益时主动退回具体类型。

## 官方参考

- TypeScript Handbook, [Generics](https://www.typescriptlang.org/docs/handbook/2/generics.html)：泛型参数、约束、相关类型参数与推断。
- TypeScript Handbook, [Keyof Type Operator](https://www.typescriptlang.org/docs/handbook/2/keyof-types.html) 与 [Indexed Access Types](https://www.typescriptlang.org/docs/handbook/2/indexed-access-types.html)：键和值关系。
- TypeScript Handbook, [Mapped Types](https://www.typescriptlang.org/docs/handbook/2/mapped-types.html)、[Conditional Types](https://www.typescriptlang.org/docs/handbook/2/conditional-types.html) 与 [Utility Types](https://www.typescriptlang.org/docs/handbook/utility-types.html)：标准变换、分布和 `infer`。
- Node.js, [Node.js Releases](https://nodejs.org/en/about/previous-releases)：Node 24 官方 LTS 状态；版本状态与本机验证范围是两件事。
