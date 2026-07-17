---
schema_version: 2
edition: 2026.2-draft
id: ch.ts.foundations
title: 类型标注、推断、数组、对象、元组与函数类型
responsibility: 建立 TypeScript 编译时类型、推断、基础标注和函数签名的最小模型，明确类型在运行时会被擦除，不提前教授联合收窄或高级泛型。
volume: '08'
order: 15
level: L1-L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.ts.foundations.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.collections
version_surfaces:
- typescript
- node-24-lts
- pnpm
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“类型标注、推断、数组、对象、元组与函数类型”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - ts-basic-types-inference
  - ts-function-object-shape
  covers_topics:
  - ts.type-annotation
  - ts.type-inference
  - ts.primitive-array-object
  - ts.tuple
  - ts.type-erasure
  - ts.function-type
  - ts.optional-readonly-property
  - ts.structural-typing-intro
  - ts.compiler-diagnostic
  uses_capabilities:
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“类型标注、推断、数组、对象、元组与函数类型”构建可运行程序与测试：把一组 JavaScript 工单函数迁为严格 TypeScript 并保存正负编译证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - ts-basic-types-inference
  - ts-function-object-shape
  covers_topics:
  - ts.type-annotation
  - ts.type-inference
  - ts.primitive-array-object
  - ts.tuple
  - ts.type-erasure
  - ts.function-type
  - ts.optional-readonly-property
  - ts.structural-typing-intro
  - ts.compiler-diagnostic
  uses_capabilities:
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: tsc-noemit-type-error-fixture-runtime-contrast
- id: diagnose
  kind: fault-diagnosis
  text: 面对“把类型当运行时校验、错误推断或可选属性未处理导致的编译/运行偏差”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ts-basic-types-inference
  - ts-function-object-shape
  covers_topics:
  - ts.type-annotation
  - ts.type-inference
  - ts.primitive-array-object
  - ts.tuple
  - ts.type-erasure
  - ts.function-type
  - ts.optional-readonly-property
  - ts.structural-typing-intro
  - ts.compiler-diagnostic
  uses_capabilities:
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 类型标注、推断、数组、对象、元组与函数类型

TypeScript 不会把 JavaScript 变成另一套运行时。它在程序运行前读取源码，依据标注、推断和编译选项检查值的使用方式，再输出仍由 JavaScript 引擎执行的代码。类型标注在输出中被擦除；浏览器、Node、HTTP 客户端和数据库不会因为函数参数写了 number 就自动拒绝字符串。理解这一点，才能把“编译期证据”和“运行时证据”放在正确边界。

本章建立最小模型：什么时候写类型标注，什么时候依赖推断；如何描述基本值、数组、对象、元组和函数签名；可选与只读属性各自保证什么；TypeScript 如何按对象成员判断兼容；怎样阅读第一个编译器诊断；以及怎样用 tsc --noEmit、故意失败的类型样例与移除类型后的运行对照保存证据。本章不提前教授 interface、type 别名、联合建模、unknown 收窄、never 或高级泛型，它们由后续章节承担。

## 完成定义与 canonical 预言

完成本章需要交出：

1. 在 120 秒内解释标注、推断、数组、对象、元组、函数类型、可选和只读属性、结构化类型入门、类型擦除与编译诊断，并给出一个类型系统不应独自解决的反例。
2. 把一组 JavaScript 工单函数迁移成严格 TypeScript；输入、源码、锁文件、编译命令与运行输出可从独立目录复现。
3. 保存正证据：合法样例在固定 TypeScript 版本下通过 tsc --noEmit，编译后的 JavaScript产生预期业务输出。
4. 保存负证据：故意的对象形状、函数签名和可选属性错误在预期文件失败；把外部输入当作已校验对象的样例在运行时暴露偏差。
5. 修复故障后重跑原命令，而不是换一套更宽松配置绕过诊断。

canonical T1 预言是：**合法样例通过 tsc --noEmit，故意的形状与函数签名错误在预期位置失败，移除类型后运行时行为对照明确。**

这里有三种不同证据。noEmit 证明目标源码在目标编译配置下通过静态检查；负样例证明检查器确实拦截预期错误，而不是配置根本没有包含文件；运行时对照证明类型擦除后 JavaScript 引擎不会替你做边界校验。任何一种都不能替代另外两种。

## 两个时间点：检查时与运行时

先建立最重要的时间轴：

    .ts 源码
       │
       ├── TypeScript 检查：读取标注、推断类型、产生诊断
       │
       └── 发射 JavaScript：类型语法被移除
                    │
                    └── Node/浏览器运行：只看到 JavaScript 值

例如：

~~~ts
// workOrderId 的标注约束 TypeScript 调用点；函数运行时只接收一个 JavaScript 值。
function formatWorkOrder(workOrderId: number): string {
  return "WO-" + workOrderId.toFixed(0);
}
~~~

若 TypeScript 源码调用 formatWorkOrder("42")，编译器会报告参数形状不匹配。但来自 JSON.parse、JavaScript 调用者、网络响应或不受检查的构建产物仍可能在运行时传入字符串；输出 JavaScript 没有 number 标注。此时 toFixed 不存在，程序才在运行时失败。

因此正确边界是：

- 类型检查保护被同一项目配置纳入检查的源码关系。
- 外部输入仍要在运行时解析与校验。
- 类型断言、注释或文件扩展名不会改变网络数据。
- 测试仍要验证业务行为，类型通过不等于算法正确。

反例：服务器返回 status: 17，而代码期望文本状态。仅给响应变量写一个对象标注不会验证这份数据；边界解析与运行时校验属于后续建模能力或验证库，不由本章基础标注自动解决。

## 类型标注：在边界写意图

类型标注是程序员显式写出的检查约束。最常见位置是变量、函数参数与返回值：

~~~ts
// retryLimit 是明确的配置边界，标注让后续赋值保持数值语义。
let retryLimit: number = 3;

// 参数说明调用合同，返回标注明确函数必须产生字符串。
function makeLabel(id: string, attempt: number): string {
  return id + "#" + attempt;
}
~~~

并不是每个局部变量都应该标注。过度标注会重复编译器已经知道的信息，增加噪声；完全不标注公共函数参数又会失去调用合同。一个实用起点是：

- 函数参数写清标注，因为参数值由调用者提供。
- 重要公共返回边界可显式标注，防止实现改动悄悄改变结果。
- 简单局部常量优先让编译器推断。
- 空集合、延迟初始化或上下文不足的位置补充标注。

“标注越多越类型安全”并不成立。写错的断言可能让检查器相信错误前提，宽松编译选项也会削弱检查。安全来自准确模型、严格配置和运行时边界共同作用。

## 类型推断：编译器从赋值与上下文得出约束

TypeScript 能从初始值推断常见类型：

~~~ts
// 编译器从初始值推断 retryLimit 为 number，无需重复写注解。
const retryLimit = 3;

// 映射回调的 item 来自 orders 数组，因此能获得对象成员提示。
const labels = orders.map((item) => item.id + ":" + item.status);
~~~

第二个例子是上下文推断：map 的回调位置提供了参数应具备的形状。推断不是运行采样，也不会查看某次真实数据；它只依据源码与声明关系计算。若初始化信息太少，得到的类型可能不符合后续意图：

~~~ts
// 空数组没有业务成员信息；在边界处应显式描述元素形状。
const queue: { readonly id: string; attempts: number }[] = [];
queue.push({ id: "WO-17", attempts: 0 });
~~~

修复错误推断时，不要第一反应使用类型断言压住诊断。先问：数据源是什么？初始化时是否缺少业务信息？函数边界是否没有标注？编译器纳入了哪些文件与库？把信息补在最接近真实合同的位置，通常比在消费点逐个断言更可维护。

## 基本值：类型描述可用操作，不是格式验证

string、number、boolean 描述 JavaScript 的基本值类别。number 同时覆盖整数与浮点数；它不会保证“非负”“金额保留两位”或“工单编号恰为八位”。string 不会保证非空、日期格式或枚举集合。boolean 也不表达“该字段已由服务器确认”。

~~~ts
// 参数类型允许字符串拼接，但日期格式和非空规则仍需业务验证。
function describeVisit(dateText: string, confirmed: boolean): string {
  return confirmed ? "confirmed@" + dateText : "pending@" + dateText;
}
~~~

null 与 undefined 的处理受 strictNullChecks 等配置影响。本章的 strict 配置把“可能缺失”当真实风险；遇到可选属性时先检查是否存在，再调用字符串方法。这里不展开联合类型语法与控制流收窄理论，只训练最小防护。

JavaScript 的大写构造器类型 String、Number、Boolean 表示包装对象概念，基础数据建模通常使用小写 string、number、boolean。不要为了“看起来像类”而写大写类型。

## 数组：同类元素的可变序列

元素类型后接方括号描述数组：

~~~ts
// orders 是唯一数据源；元素必须同时具有 id 与 closed 成员。
const orders: { readonly id: string; closed: boolean }[] = [
  { id: "WO-1", closed: false },
  { id: "WO-2", closed: true }
];

// 回调返回 boolean，filter 因而仍产生同形状对象数组。
const openOrders = orders.filter((order) => !order.closed);
~~~

数组类型约束元素操作：push 缺少成员的对象会产生诊断，读取元素可获得成员提示。它不保证数组非空，也不保证索引存在。配套配置启用 noUncheckedIndexedAccess，使 orders[0] 的使用必须考虑不存在；这属于项目选择，官方 strict 总开关本身不自动包含每个额外严格选项。

readonly 元素属性与只读数组是两件事。readonly id 阻止通过该对象类型给 id 重新赋值；只读数组则阻止 push、splice 等结构修改。本章示例会在不应修改输入的函数参数上使用 readonly 数组语法，表达“函数读取而不改变集合”的意图。

~~~ts
// 参数数组只读，避免汇总函数对调用者集合产生结构副作用。
function countOpen(orders: readonly { closed: boolean }[]): number {
  return orders.filter((order) => !order.closed).length;
}
~~~

只读仍是编译期约束，不是深冻结。JavaScript 输出中没有自动 Object.freeze；另一个不受此类型约束的引用仍可能修改同一对象。

## 对象形状：关心成员，而不是名义标签

对象类型描述需要哪些属性以及每个属性的类型：

~~~ts
// 参数对象的形状就是此函数真正消费的最小合同。
function renderSummary(order: {
  readonly id: string;
  status: string;
  assignee?: string;
}): string {
  const owner = order.assignee === undefined ? "unassigned" : order.assignee;
  return order.id + ":" + order.status + ":" + owner;
}
~~~

readonly id 表示通过这个类型观察对象时不能重新赋值 id；assignee 后的问号表示该属性可以不存在。读取可选属性时，必须先处理缺失情况。optional 不等于“任何值都可以”；在本章 exactOptionalPropertyTypes 配置下，属性缺席与显式写 undefined 会被更严格地区分，除非类型合同明确允许后者。

对象类型不要求值由某个特定构造器创建。只要一个值具有调用点需要的成员，通常就能传入，这就是结构化类型的最小直觉：

~~~ts
// extra 字段不妨碍这个已有变量满足 renderSummary 需要的成员形状。
const rowFromCache = {
  id: "WO-9",
  status: "OPEN",
  assignee: "Lin",
  cachedAt: 1700000000
};

renderSummary(rowFromCache);
~~~

TypeScript 看的是所需成员，不是“类名相同”。但对象字面量直接放到某些上下文时会接受额外属性检查，帮助发现拼写错误；把值先存变量后再传入，兼容性判断的表现可能不同。这里先学会阅读诊断，不把这种检查误说成精确对象封闭机制。interface、type 别名与更完整业务建模留给下一章。

### 可选属性的安全读取

错误：

~~~ts
// 错误意图：assignee 可能缺席，直接调用方法会产生严格模式诊断。
function upperOwner(order: { assignee?: string }): string {
  return order.assignee.toUpperCase();
}
~~~

最小修复：

~~~ts
// 缺席策略由业务明确为 UNASSIGNED，而不是用断言隐藏风险。
function upperOwner(order: { assignee?: string }): string {
  if (order.assignee === undefined) {
    return "UNASSIGNED";
  }
  return order.assignee.toUpperCase();
}
~~~

默认值是否正确是业务决定。若“未分配”必须阻止流程，就不该悄悄返回占位文本。类型系统能指出缺失可能，不能替产品决定缺失策略。

## 元组：固定位置具有不同职责

普通数组适合同类、长度可能变化的集合；元组适合少量固定位置，每个位置语义不同。例如工单状态变更的前后值：

~~~ts
// 第零位是旧状态，第一位是新状态；位置映射是这个元组的合同。
const transition: readonly [string, string] = ["OPEN", "CLOSED"];
const before = transition[0];
const after = transition[1];
~~~

元组在 JavaScript 运行时仍是数组，没有专属运行表示。类型擦除后，运行时不会阻止 push，也不会给位置自动命名。若位置超过两三项、含义难记或需要跨边界传输，对象通常更清楚：

    ["WO-1", "OPEN", 3, true]       // 位置含义难以审计
    { id: "WO-1", status: "OPEN", attempts: 3, urgent: true }

选择元组不是为了少打字，而是因为固定位置本身就是协议。配套练习只使用短元组，不提前引入可变元组与泛型操作。

## 函数类型：约束参数与结果

函数也是值，可以作为参数传递。函数类型描述调用者能传什么以及返回什么：

~~~ts
// formatter 是注入的数据映射；调用者必须提供两个字符串参数并返回字符串。
function buildLabels(
  orders: readonly { readonly id: string; status: string }[],
  formatter: (id: string, status: string) => string
): string[] {
  return orders.map((order) => formatter(order.id, order.status));
}
~~~

这段合同让 buildLabels 不需要知道展示格式，并能在调用点检查 formatter。参数名 id 与 status 帮助阅读，但兼容性主要由参数位置和类型决定；仅改参数名不会产生名义差异。

返回值标注值得用于关键边界：

~~~ts
// 明确返回 number，防止未来实现改成格式化字符串却悄悄传播。
function totalAttempts(orders: readonly { attempts: number }[]): number {
  return orders.reduce((sum, order) => sum + order.attempts, 0);
}
~~~

若回调只为了副作用，TypeScript 有 void 相关规则；它们比“函数绝不能产生任何 JavaScript 返回值”更细。基础阶段只记住：业务上依赖结果就写出结果类型，事件处理器不应把偶然返回值当协议。异步函数、Promise 与错误传播已由事件循环章节负责，本章不扩展。

### 函数签名错误如何成为负证据

若 formatter 需要 number 状态码，却传给要求 string 状态的 buildLabels，编译器应在调用关系上报告不兼容。负样例必须单独放置并由专门命令检查：

- 预期命令非零退出；
- 输出指向故障 fixture，而非依赖安装或配置文件语法；
- 诊断类别符合“参数/返回形状不兼容”；
- 基线源码仍单独通过。

仅保存一张编辑器红线截图不够，因为编辑器版本、项目加载状态和插件会变化。保存固定 tsc 版本、命令、退出码与文本日志更可复现。

## readonly：禁止这个观察路径写入，不是深度不可变

readonly 属性的准确语义是：通过声明为 readonly 的属性访问路径，TypeScript 不允许赋值。它不会：

- 在输出 JavaScript 中冻结对象；
- 递归冻结嵌套对象；
- 阻止另一个可写别名修改同一值；
- 保护来自不受检查 JavaScript 的写入；
- 代替数据库不可变约束。

~~~ts
// 此函数只承诺不改 id；status 仍按合同允许更新。
function closeOrder(order: { readonly id: string; status: string }): void {
  order.status = "CLOSED";
}
~~~

readonly 适合表达函数责任边界。若业务需要不可变更新、并发一致性或审计历史，还需要运行时与数据层设计。本章不把一个关键字夸大成架构保证。

## 结构化类型的入门诊断法

当看到“某值不能赋给某参数”时，从最外层形状逐层比较：

1. 目标需要哪些属性？
2. 实际值缺少哪个属性，或哪个属性类型不同？
3. 若是函数，参数位置与返回结果哪里不同？
4. 若是数组，错误来自数组本身还是某个元素？
5. 若是元组，错误来自长度还是特定位置？
6. 诊断链中哪个是最早由自己源码控制的差异？

不要从最长、最底层的库类型名开始恐慌。TypeScript 诊断经常从赋值点列出一条关系链；先找到自己文件中的首个位置，再向内读“property X is missing”或“type A is not assignable to type B”一类核心句子。

结构化兼容不是运行时验证。一个 JSON 对象在运行时碰巧有相同字段，不会先经过 TypeScript 检查；只有把它带入受检查源码时，检查器才依据你声明的信息推理。若你用断言直接宣称其形状，检查器会按声明继续，但真实数据仍可能不同。

## 编译器诊断：错误是证据，不是敌人

一个可复现诊断至少记录：

- TypeScript 精确版本；
- tsconfig 路径与关键选项；
- 执行命令与工作目录；
- 退出码；
- 首个相关文件、行列和诊断编号；
- 修复后原命令的结果。

例如先运行：

    pnpm exec tsc --project tsconfig.json --noEmit --pretty false

pretty false 让日志在非交互环境更稳定，但具体诊断编号和措辞仍可能随 TypeScript 版本变化。不要把整段英文文案作为永久 API；负 fixture 可以同时核对非零退出、目标文件名和关键错误类别。

常见误诊：

- 实际是文件没被 include，却以为“无错误代表类型正确”。
- 命令使用全局 tsc，而项目锁定版本没有执行。
- skipLibCheck 或宽松选项掩盖了预期检查。
- 负样例与基线一起 include，导致合法构建永远失败。
- 修改 tsconfig 关闭 strict 来“修复”源码。
- 第一条错误是依赖未安装，却去改业务类型。

修复原则是保持验证合同不变：同一版本、同一 tsconfig、同一命令。若确实要改配置，这是项目级决策，应说明影响与迁移，不应混进一次局部类型修复。

## strict 与显式附加选项

官方 strict 选项启用一组更严格检查，并说明未来 TypeScript 版本升级可能在 strict 下产生新诊断。为了让练习意图明确，配套资产还显式启用：

- noEmit：正检查不生成 JavaScript，避免把“检查”与“运行”混在一起。
- exactOptionalPropertyTypes：更准确地区分可选属性缺席与显式 undefined。
- noUncheckedIndexedAccess：数组或索引读取考虑不存在。
- noImplicitOverride、noFallthroughCasesInSwitch 等不属于本章核心，不在这里扩展。

运行时对照另用一个继承基础选项的 emit 配置，把输出放入临时目录；验证结束后删除，不污染资产目录。这样可以同时保存“noEmit 检查通过”和“擦除类型后的 JavaScript 确实运行”两种证据。

## 类型擦除：查看输出，而不是相信口号

输入：

~~~ts
// 标注仅用于检查；函数没有注入任何运行时校验副作用。
export function normalizeId(id: number): string {
  return "WO-" + id.toFixed(0);
}
~~~

概念上的输出：

~~~js
// TypeScript 发射后只剩 JavaScript 参数；运行时不会检查 number。
export function normalizeId(id) {
  return "WO-" + id.toFixed(0);
}
~~~

运行时对照应包含两条路径：

1. 受检查 TypeScript 调用传入数值，tsc 通过，输出按预期。
2. 独立 JavaScript 边界把字符串传给发射函数，JavaScript 仍尝试执行，可能报错或产生与业务合同不同的结果。

第二条不是鼓励绕过类型，而是证明防线边界。若外部数据重要，正确做法是在入口校验并只把已验证值交给核心函数；具体 unknown 收窄和运行时 schema 留给后续章节。

类型断言同样会被擦除。它表示“程序员向检查器提供信息”，不是插入 if 检查。把断言称为“强制类型转换”容易误导，因为多数断言不会转换运行时值。Number(input) 之类 JavaScript 操作才可能实际转换，但转换结果仍需验证。

## 从 JavaScript 工单函数迁移的顺序

不要一次给整个文件加满标注。建议按可验证的边界推进：

1. 保存原 JavaScript 输入和输出，确认当前行为。
2. 固定 TypeScript 版本与 strict tsconfig，先确保目标文件真的被 include。
3. 给公共函数参数和重要返回值写最小形状。
4. 让局部变量推断；只在空集合、延迟初始化或信息不足处补标注。
5. 把固定位置的小型协议改成元组，把同类可变集合保持为数组。
6. 对可选属性写明确缺失策略，对只读输入禁止意外修改。
7. 运行 noEmit，逐个处理最早的可信诊断。
8. 单独运行形状与函数签名负 fixture，确认门会失败。
9. 发射到临时目录并运行，与原 JavaScript 输出对照。
10. 加入一个外部坏输入对照，记录类型擦除后的真实边界。

迁移过程中不要趁机重写业务算法。若运行输出变化，就无法判断是类型迁移还是逻辑重构导致。架构重构可以另立任务，先让类型迁移拥有窄而稳定的完成定义。

## 一组最小工单实现

~~~ts
// 输入对象由调用者提供；readonly 表明汇总函数不拥有修改权。
export function summarizeOrders(
  orders: readonly {
    readonly id: string;
    status: string;
    assignee?: string;
  }[],
  formatter: (id: string, status: string, owner: string) => string
): string[] {
  return orders.map((order) => {
    const owner = order.assignee === undefined ? "UNASSIGNED" : order.assignee;
    return formatter(order.id, order.status, owner);
  });
}

// 固定两项元组表达前后状态；位置含义不会在循环中变化。
export function describeTransition(
  transition: readonly [string, string]
): string {
  return transition[0] + " -> " + transition[1];
}
~~~

这里覆盖对象形状、可选和只读属性、数组、元组与函数类型。它没有声明 interface 或 type 别名，因为下一章会比较这些建模工具；也没有把 status 限制为状态集合，因为那会进入联合建模。本章先让函数合同与运行时边界清楚。

## 三类故障的首个可信证据

### 故障一：把类型当运行时校验

注入：从 JSON 得到 id: "17"，随后用断言把对象当成 id 为 number。编译器可能按提供的信息通过，运行时调用 toFixed 时失败。首证据是运行时异常与发射 JavaScript 中不存在校验，而不是“TypeScript 坏了”。修复是入口验证或明确转换并检查结果，不是增加更多断言。

残余风险：本章私有解只展示边界失败，不提供完整 schema 验证器。生产系统还要定义错误响应、日志脱敏和字段演进策略。

### 故障二：错误推断或缺少上下文

注入：创建空集合或过窄初值，然后在后续阶段写入工单对象。首证据是赋值点的编译诊断与初始化处缺失业务形状。修复是在集合拥有者边界补元素标注，而不是让每个消费函数分别断言。

也要检查是否选错 tsconfig。一个文件由编辑器推断项目检查、命令行却没有 include，会产生“编辑器红、CI 绿”或相反结果；项目归属本身是首要证据。

### 故障三：可选属性未处理

注入：直接调用 order.assignee.toUpperCase。strict 编译器应在该读取位置报告可能缺失。修复是明确缺失策略，再重跑同一个 noEmit。使用非空断言只会让诊断消失，不会保证数据存在，不能作为本练习修复。

### 故障四：函数签名不匹配

注入：给 formatter 传入错误参数类型或返回 number。首证据应指向负 fixture 的调用关系。修复调用合同或实现；不要把 formatter 参数改成无约束逃逸类型。本章资产会要求负 fixture 确实非零退出，避免类型门空跑。

## 配套四类资产

每个目录自包含 package.json、锁文件、tsconfig、源码和唯一可执行 verify.sh，并固定 typescript 7.0.2：

- example：严格 noEmit 通过，发射到临时目录后运行工单汇总；另有 JavaScript 坏输入证明类型被擦除。
- lab：合法基线先通过，形状错误、函数签名错误和可选属性错误分别按预期失败，运行时类型误信产生稳定故障标记。
- public exercise：初始源码直接读取可选 assignee，验证应输出 UNSAFE_OPTIONAL_ACCESS_EXERCISE 并非零退出；学员实现明确缺失策略后同一命令转绿。
- private solution：独立实现完整合同、运行断言和类型擦除对照，默认全绿。

verify.sh 使用项目本地 tsc，不依赖全局安装；先离线按锁文件安装，再清理 node_modules。这样锁文件与依赖缓存成为可复现输入的一部分。离线成功仍不证明 Node 24 目标环境已验证；本机机械验证环境会单独报告。

## FactoryCare 项目中的落点

FactoryCare 工单核心函数可以先用基础形状表达：

- 只读 id：函数不能意外重写标识。
- status 字符串：基础章只描述字符串，合法状态集合留给联合建模。
- 可选 assignee：每个消费点必须定义未分配策略。
- 工单数组：批量汇总不修改调用者集合。
- readonly [before, after]：短小状态变更对照。
- formatter 函数参数：把展示映射与数据遍历分开。

HTTP 响应进入时仍是不可信运行时数据。不能因为变量标注为工单数组就删除服务端合同测试。理想目标状态是：边界负责验证，核心函数接收可信形状，tsc 检查核心调用关系，运行测试证明业务输出；每层证据都只承担自己的责任。

## 120 秒口述模板

“TypeScript 在运行前检查 JavaScript 源码关系。参数和返回标注适合写合同，简单局部值可由初值或上下文推断；数组表示同类集合，元组表示少量固定位置；对象按所需成员进行结构化兼容。可选属性可能缺席，必须写业务策略；readonly 只限制这个类型路径的写入，不会深冻结。函数类型约束参数位置和结果。tsc --noEmit 是合法样例的静态证据，故意错误 fixture 证明门能拦截形状与签名问题；发射后的 JavaScript 删除类型，所以外部输入仍需运行时校验。反例是服务器返回错误字段类型，给变量加标注不会验证响应。”

若回答把类型称为运行时校验、把 readonly 称为 Object.freeze，或无法说明一个负 fixture 的首个诊断，explain outcome 尚未完成。

## 版本表面与官方资料

本章资产固定 TypeScript 7.0.2，并在 packageManager 字段声明 pnpm 11.11.0、在 engines 字段声明 Node 24.x。官方 TypeScript 团队在 2026 年 7 月发布 7.0；这是非常新的版本表面，编译器实现、默认行为、诊断文案和安装包组成可能继续变化。核心 JavaScript 运行时与类型擦除模型较稳定，但本章 canonical 将 typescript、node-24-lts 和 pnpm 都列为版本表面，所以升级必须重跑正负 fixture 与运行对照。

资料核对日期为 2026-07-17：

- TypeScript 官方 Everyday Types：https://www.typescriptlang.org/docs/handbook/2/everyday-types.html
- TypeScript 官方 Object Types：https://www.typescriptlang.org/docs/handbook/2/objects
- 官方 strict 配置说明：https://www.typescriptlang.org/tsconfig/strict.html
- 官方 noEmit 配置说明：https://www.typescriptlang.org/tsconfig/noEmit.html
- 官方 exactOptionalPropertyTypes 说明：https://www.typescriptlang.org/tsconfig/exactOptionalPropertyTypes.html
- 官方下载与项目本地安装说明：https://www.typescriptlang.org/download/
- TypeScript 7.0 官方发布说明：https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/
- Node.js 官方发布与 LTS 页面：https://nodejs.org/en/about/previous-releases
- pnpm 的 npm 注册表版本页：https://www.npmjs.com/package/pnpm?activeTab=versions

官方 strict 页面明确提醒：未来版本升级可能在 strict 下产生新的类型错误。这是升级重新验证的理由，不是关闭 strict 的理由。项目应固定精确依赖与锁文件，在单独变更中评估诊断迁移和回滚。

配套资产声明 canonical 目标 Node 24 LTS 与 pnpm，但若本地只在其他 Node/pnpm 版本上执行，必须将结果标为局部机械验证，不能声称目标矩阵通过。TypeScript 7.0.2 的平台包也由锁文件解析，跨操作系统验证应在对应环境重新安装。

## 有意不覆盖与兼容策略

本章有意不覆盖 interface、type 别名、联合与交叉类型、unknown、用户自定义类型守卫、never 穷尽检查、泛型、类、装饰器、声明文件发布、项目引用、运行时 schema 库和 JavaScript 文件渐进检查。这些不是遗漏，而是防止基础模型与下一章职责重叠。

没有为旧 TypeScript 版本保留双配置或诊断兼容层。精确固定 7.0.2 优先保证证据可复现；若项目必须继续使用旧编译器，应作为显式兼容选项，单独评估语法、配置、安装、迁移与回滚。没有把断言或非空断言当兼容补丁，因为那会牺牲长期可维护性。

最终完成边界仍是 canonical 预言：合法样例通过固定版本 noEmit，故意的形状和函数签名错误在预期位置失败，发射后运行对照明确展示类型擦除；任何未在 Node 24、目标 pnpm 或目标操作系统执行的矩阵都必须如实列为未验证。
