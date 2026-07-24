---
schema_version: 2
edition: 2026.2-draft
id: ch.js.testing-debugging
title: 异常、调试、测试预言与 Vitest
responsibility: 在 JavaScript 中落实异常边界、调试器、AAA、Vitest 断言和可隔离替身，只覆盖语言单元测试，不声称已掌握 Vue 组件或浏览器端到端测试。
volume: '08'
order: 9
level: L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.testing-debugging.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.collections
version_surfaces:
- node-24-lts
- pnpm
- vitest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“异常、调试、测试预言与 Vitest”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-errors-debugging
  - js-vitest-unit
  covers_topics:
  - js.error-throw-catch
  - js.error-cause-stack
  - js.debugger-breakpoint
  - js.failure-stage-evidence
  - js.vitest-test-suite
  - js.aaa-test-structure
  - js.assertion-oracle
  - js.test-double-boundary
  - js.test-isolation
  uses_capabilities:
  - web.javascript-language
  - foundation.verification-debug-test
  - web.javascript-testing-debugging
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单纯函数建立 Vitest 正常、边界和异常测试并保存一次红绿重构证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-errors-debugging
  - js-vitest-unit
  covers_topics:
  - js.error-throw-catch
  - js.error-cause-stack
  - js.debugger-breakpoint
  - js.failure-stage-evidence
  - js.vitest-test-suite
  - js.aaa-test-structure
  - js.assertion-oracle
  - js.test-double-boundary
  - js.test-isolation
  uses_capabilities:
  - web.javascript-language
  - foundation.verification-debug-test
  - web.javascript-testing-debugging
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: vitest-unit-debugger-injected-fault
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误预期、未等待异步、共享夹具或捕获异常后静默通过”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-errors-debugging
  - js-vitest-unit
  covers_topics:
  - js.error-throw-catch
  - js.error-cause-stack
  - js.debugger-breakpoint
  - js.failure-stage-evidence
  - js.vitest-test-suite
  - js.aaa-test-structure
  - js.assertion-oracle
  - js.test-double-boundary
  - js.test-isolation
  uses_capabilities:
  - web.javascript-language
  - foundation.verification-debug-test
  - web.javascript-testing-debugging
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 异常、调试、测试预言与 Vitest

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《数组、对象、Map、Set 与不可变更新》](ch.js.collections.md)：夹具、输入案例和结果断言需要能独立处理集合与对象。
<!-- END GENERATED LEARNING PREREQUISITES -->

程序打印绿色“完成”不等于结果正确，测试进程退出 0 也不等于关键行为被验证。一个没有断言的测试、一个被 `catch` 吞掉的错误、一个没有 `await` 的异步断言、一个被上一用例污染的共享夹具，都可能产生危险的假阳性。本章的中心不是“会写 `expect`”，而是建立可信证据链：明确失败属于哪个阶段，用独立预言判断值，故意改坏实现证明测试真的能红，再修复并让同一测试恢复。

我们只覆盖 JavaScript 语言单元测试。Vitest 用来组织 suite、运行断言和替换边界依赖；不因此声称已经测试 Vue 组件、真实浏览器、网络、数据库或端到端用户旅程。FactoryCare 案例是一段工单摘要纯函数和一个显式加载端口，前端测试不重建或授权服务端状态机。

## 完成定义与 canonical 预言

完成本章必须留下：

1. 在 120 秒内解释异常边界、`cause/stack`、断点、失败阶段、AAA、测试预言、替身和隔离，并给出不由本章解决的反例；
2. 为工单纯函数写正常、空输入边界、异常输入和输入不变测试，再用可控替身验证一次异步加载边界；
3. 保存一次“测试先绿—故意改坏—预期断言红—修复—原测试绿”的证据；
4. 对错误预期、未等待异步、共享夹具、捕获后静默四类故障指出首个可信证据。

canonical T2 预言是：**正常、边界和故障用例均由独立预言验证；故意改坏实现后 Vitest 在预期断言处失败，修复后原测试恢复。** “独立”意味着 expected 不能直接调用受测实现计算自己；“预期断言处”意味着不是依赖安装失败、语法错误或错误测试文件路径制造红灯。

## 失败阶段先分类

一条验证链通常经过：

```text
依赖/配置 → 解析与模块加载 → 测试收集 → Arrange → Act → Assert → 清理 → 进程退出
```

不同阶段的证据不同：

| 阶段 | 常见现象 | 首个可信证据 | 不应得出的结论 |
| --- | --- | --- | --- |
| 安装/配置 | 找不到 Vitest、lockfile 不一致 | 包管理器错误与实际版本 | “业务实现有 bug” |
| 解析/加载 | SyntaxError、导出不存在 | 文件、行号、模块栈 | “断言证明失败” |
| 收集 | 0 tests、错误 include | 收集摘要与文件模式 | “所有测试通过” |
| Arrange | 夹具创建失败 | setup 栈与输入 | “Act 逻辑错误” |
| Act | 受测函数抛错/拒绝 | 错误类型、消息、cause | “expected 写错” |
| Assert | actual/expected diff | matcher 行与差异 | “运行环境坏了” |
| 清理 | mock/时钟/全局未恢复 | 后续用例顺序依赖 | “偶发、重跑就好” |

调试第一问是“执行到了哪一层”，而不是马上改源码。若测试文件根本没被收集，绿色命令甚至没有触碰受测行为。

## throw、Error 与 catch 边界

JavaScript 可以 `throw` 任意值，但工程代码优先抛 `Error` 或语义明确的子类，因为它们携带名称、消息、可追踪身份，宿主通常还提供 stack：

```js
// summarizeWorkOrders 在语言边界验证输入形状，错误消息描述违反的合同。
export function summarizeWorkOrders(workOrders) {
  if (!Array.isArray(workOrders)) {
    throw new TypeError("workOrders must be an array");
  }
}
```

`throw "bad"` 虽合法，却让调用者难以用 `instanceof Error`、`name` 或 `cause` 诊断。消息服务人读，不应成为随意拼接敏感字段的日志容器。

### catch 只捕获能处理的层

```js
// loadSummary 给底层错误增加当前动作上下文，同时保留原始 cause。
export async function loadSummary(loadOrders) {
  try {
    const orders = await loadOrders();
    return summarizeWorkOrders(orders);
  } catch (cause) {
    throw new Error("work-order summary load failed", { cause });
  }
}
```

边界可以转换错误、补充上下文或恢复；不能处理就继续抛出。下面是危险假阳性：

```js
// 错误：异常被吞掉，调用者得到 undefined，测试也可能没有任何断言。
try {
  await loadSummary(loadOrders);
} catch (_error) {
  // 什么也不做
}
```

若合同是“错误必须传播”，测试应 `await expect(promise).rejects...`；若合同是“降级为明确结果”，catch 必须返回带类型/状态的降级值并记录可观测证据。沉默不是恢复策略。

### finally 的职责

`finally` 无论 try 正常、return 或 throw 通常都会执行，适合释放当前函数实际拥有的资源。不要在 finally 中 return 新值或抛无关错误覆盖原结果。单元测试的 cleanup 也遵守所有权：恢复自己替换的时钟、spy、环境变量，不删除其他测试创建的数据。

### cause 与 stack 各能证明什么

`Error` 的 `cause` 可保留底层错误对象，帮助沿包装边界追踪。`stack` 的具体字符串格式和帧展示由宿主实现，Node 与浏览器可能不同；测试不要逐字快照整条 stack。稳定断言可检查：

- 外层错误是预期类型；
- `message` 表达当前边界；
- `cause` 与原错误是同一对象，或至少具备预期类型/码；
- stack 存在时用于人工定位，不作为跨引擎业务合同。

错误类型也不是 HTTP 状态或用户文案。服务端到 UI 的错误映射需 API 合同，本章不设计。

## debugger 与断点：暂停并检查假设

`debugger;` 在附加调试器时触发暂停，没有调试器时通常不产生业务结果。断点的价值是让你在状态变化前后比较，而不是逐行漫游整个程序。

最小调试流程：

1. 从失败断言写出一个假设，如“第二条输入把共享夹具长度改为 3”；
2. 在最早可能形成差异的位置设断点；
3. 检查参数、局部绑定、引用身份与调用栈；
4. 单步越过一个有意义操作；
5. 比较预测与实际；
6. 找到更早原因时移动断点，不靠添加随机日志掩盖；
7. 修复后删除教学 `debugger` 并重跑原测试。

条件断点适合只在 `workOrder.id === "WO-2"` 时暂停；logpoint 可临时记录且不改源码。DevTools 面板名称会随浏览器版本变化，本章记录概念与观察，不锁定每个按钮位置。

### 断点不是测试预言

人工看到变量为 2 只证明一次观察，不能自动防回归。断点用来找到原因，断言把规则保存下来。反过来，失败断言告诉你“哪里与预期不同”，未必告诉你“为何不同”，仍需调用栈、输入和状态追踪。

## 测试是什么：输入、操作、预言

一个单元测试至少回答：

- 受测责任是什么；
- 输入与依赖是什么；
- 执行哪个操作；
- 什么结果必须成立；
- 失败时哪条信息能定位合同；
- 哪些副作用必须不存在或被观察。

Vitest 的基本结构：

```js
import { describe, expect, it } from "vitest";
import { summarizeWorkOrders } from "../src/work-order-summary.mjs";

describe("summarizeWorkOrders", () => {
  it("counts a normal fixture without mutating it", () => {
    // Arrange：固定输入与独立 expected。
    const input = [
      { id: "WO-1", status: "CREATED" },
      { id: "WO-2", status: "ASSIGNED" },
    ];
    const before = structuredClone(input);

    // Act：只调用一次受测责任。
    const result = summarizeWorkOrders(input);

    // Assert：同时验证值与输入所有权。
    expect(result).toEqual({
      total: 2,
      counts: { CREATED: 1, ASSIGNED: 1 },
    });
    expect(input).toEqual(before);
  });
});
```

AAA 不是强制三段注释，而是保持因果清楚。一个测试若同时启动服务器、登录、创建工单、点击 UI、查数据库，就不再是语言单元测试。

## 测试名称是一条可执行合同

“works”或“test 1”无法在失败列表中说明风险。名称应包含条件与可观察结果：

- `returns zero counts for an empty array`；
- `throws TypeError when input is not an array`；
- `does not mutate caller-owned work orders`；
- `wraps loader rejection and preserves cause`。

不要把实现步骤写进名称，如“calls reduce”。重构从 `reduce` 改成循环不应让行为测试失效。

## 正常、边界和异常不是三个随意样本

### 正常用例

选择典型且足以区分规则的输入。按状态计数至少要有两个状态和一个重复状态，否则“每个状态固定写 1”的错误实现也可能绿。

### 边界用例

边界来自合同：空数组应得到 `total: 0, counts: {}`；单元素；重复 ID 是否允许；输入对象是否保持不变。不要为了凑数测语言本身的 `1 + 1`。

### 异常用例

异常测试证明拒绝非法输入：

```js
// 传函数给 toThrow，让 Vitest 执行并观察同步异常。
expect(() => summarizeWorkOrders(null)).toThrow(TypeError);
expect(() => summarizeWorkOrders([{ id: "WO-1" }]))
  .toThrow("work order status is required");
```

写成 `expect(summarizeWorkOrders(null)).toThrow()` 会在进入 `expect` 前就抛出，测试框架无法用该 matcher 捕获。异步拒绝则使用 `await expect(promise).rejects...`。

## assertion oracle：谁告诉你什么是对

预言可以来自：

- 明确业务规则与手算表；
- 规范/协议例子；
- 经过审查的固定快照；
- 与实现独立的参考算法；
- 状态/引用不变量；
- 已知故障必须触发的 metamorphic relation。

错误做法：

```js
// 反例：expected 调用同一实现，任何同源错误都会同时出现。
const actual = summarizeWorkOrders(input);
const expected = summarizeWorkOrders(input);
expect(actual).toEqual(expected);
```

另一个反例是复制生产算法到测试，只改变量名。若两边都把 `CANCELLED` 错算为活动工单，测试仍绿。对小纯函数，用手算案例表通常更可信。

### 精确 matcher 与宽松 matcher

`toBe` 使用类似 `Object.is` 的身份/原始值语义；`toEqual` 深比较结构；`toStrictEqual` 对原型、稀疏数组和 `undefined` 字段等更严格。`toBeTruthy` 只证明布尔转换为真，不能替代明确状态或计数。选择能表达风险的最窄 matcher：

```js
expect(result.total).toBe(3);
expect(result.counts).toEqual({ CREATED: 2, ASSIGNED: 1 });
expect(result).not.toBe(input);
```

不要对大型对象只断言 `toBeDefined`，那会让大量错误值通过。

## 红—绿—重构必须证明红是可信的

可靠证据顺序：

1. 写预言，确认它因缺失/错误行为在目标断言处红；
2. 保存失败测试名、actual/expected 与退出码；
3. 做最小实现使其绿；
4. 故意把一个关键操作改坏，例如总数 `+ 1`；
5. 确认同一测试在计数断言红，而不是语法/安装阶段；
6. 恢复实现，原测试绿；
7. 重构名称/结构，行为断言仍绿。

若测试从未红过，可能根本没被收集；若“故意改坏”仍绿，测试预言不敏感。不要把公开 exercise 的预期红改成 skip。

## Vitest 的最小可复现工程

`package.json` 固定包管理器和精确工具版本：

```json
{
  "private": true,
  "type": "module",
  "packageManager": "pnpm@10.18.0",
  "scripts": {
    "test": "vitest run"
  },
  "devDependencies": {
    "vitest": "4.1.10"
  }
}
```

学习资产提交 lockfile，并用：

```bash
pnpm install --frozen-lockfile
pnpm exec vitest run
```

`vitest` 默认开发命令可能进入 watch；可复现 verifier 使用 `vitest run` 一次退出。当前官方文档在 2026-07-17 显示 v4.1.10，并要求 Node ≥20；教材版本面目标是 Node 24 LTS。本机实际版本必须另行记录。

### 收集摘要也要验收

退出 0 但显示 “No test files found” 不能算绿。CI 配置应让无测试成为失败；verifier 还可以检查目标文件名和通过测试数。`.only`、`.skip`、`.todo` 会改变执行集合，提交前检查聚焦/跳过项是否符合合同。

## 异步测试：Promise 必须进入测试生命周期

```js
it("wraps a loader rejection and preserves cause", async () => {
  const cause = new Error("offline");
  const loadOrders = vi.fn().mockRejectedValue(cause);

  await expect(loadSummary(loadOrders)).rejects.toMatchObject({
    message: "work-order summary load failed",
    cause,
  });
  expect(loadOrders).toHaveBeenCalledOnce();
});
```

忘记 `await` 或 return，会让测试回调提前结束。Vitest 4 会把未等待的 `rejects/resolves` 标为失败，这是工具防线；代码仍应清楚地 await，并在复杂回调场景用 `expect.assertions(n)` 或 `expect.hasAssertions()` 证明断言执行。

定时器、事件与网络回调的异步性不在本章全面展开；后续异步/事件章节处理事件循环。这里的原则只有一条：测试必须等待它声称验证的结果。

## 测试替身：替换边界，不复制内部实现

常用词：

- stub：返回预设值，使难触发分支可控；
- spy：观察调用次数、参数、结果，同时可保留原实现；
- mock：广义上可指可编程替身，具体语义依工具；
- fake：有轻量可工作的实现，如内存仓库。

`vi.fn()` 适合注入函数端口：

```js
// loadOrders 是外部数据源端口；测试不访问真实网络或数据库。
const loadOrders = vi.fn().mockResolvedValue([
  { id: "WO-1", status: "CREATED" },
]);

const result = await loadSummary(loadOrders);
expect(result.total).toBe(1);
expect(loadOrders).toHaveBeenCalledWith();
```

替身边界越靠外越好。若为了测试一个纯函数 mock `Array.prototype.map`，说明测试绑定了实现细节。不要 mock 你不理解的第三方行为并把自编返回值当作集成证据。

### spy 的恢复

`vi.spyOn(object, "method")` 修改对象属性描述符。每个测试必须恢复自己创建的 spy，可用 `afterEach(() => vi.restoreAllMocks())` 或配置。Vitest 4 中 `restoreAllMocks` 恢复手工 spy，但不会替你清理所有自动 mock 状态；官方 API 文档是版本特定事实。

## 测试隔离：每个用例都能单独运行

理想性质：

- 单独运行与全套运行结果相同；
- 改变文件/用例顺序不改变结果；
- 夹具由每个测试新建；
- mock、时钟、环境变量和模块状态在结束后恢复；
- 测试不依赖前一个测试“先创建”数据。

危险反例：

```js
// 错误：文件级数组在两个测试之间共享。
const sharedOrders = [{ id: "WO-1", status: "CREATED" }];

it("adds a fixture", () => {
  sharedOrders.push({ id: "WO-2", status: "ASSIGNED" });
});

it("starts with one fixture", () => {
  expect(sharedOrders).toHaveLength(1); // 顺序运行时失败
});
```

修复是工厂：

```js
// freshOrders 每次返回新数组和新元素，避免浅层别名。
function freshOrders() {
  return [{ id: "WO-1", status: "CREATED" }];
}
```

Vitest 默认隔离测试文件环境不等于自动重置同一文件的模块变量、外部服务或闭包。框架隔离是保护层，夹具所有权仍由测试作者负责。

## 四类假阳性的首个可信证据

### 1. 错误 expected：untrusted-oracle

现象：实现正确却测试要求 `total === 99`，或实现/expected 复制同一错误算法。首证据是案例表手算值与 expected 不一致。修 expected 前先用业务合同或第二个区分样本确认，不因“让测试绿”就相信 actual。

### 2. 未等待异步：false-positive-test

现象：测试结束后才出现拒绝/断言，或 Vitest 报未等待 matcher。首证据是测试回调没有 return/await 该 Promise。修复后用 `expect.assertions` 和故意错误消息证明异步断言真的参与退出码。

### 3. 共享夹具：test-isolation-leak

现象：单测单独绿、全套红或顺序相关。首证据是两个用例开始时 `fixture` 引用相同或长度已变。修复为每用例新建，恢复 mock，必要时检查模块缓存与外部资源。

### 4. catch 后静默

现象：受测函数抛错，但测试 catch 后没有断言，显示通过。首证据是 catch 路径执行而 assertion count 为 0。修复用 `toThrow/rejects`，或在 catch 中明确断言错误且调用 `expect.assertions(1)`。

## FactoryCare 示例边界

工单摘要函数只对给定快照计数，不判断状态迁移合法性。`CREATED`、`ASSIGNED`、`IN_PROGRESS` 等值来自固定教学夹具；服务端 Java 仍是唯一状态机权威，负责角色、租户、原因、审批、版本、SLA、审计和事件。

单元测试也不能证明系统正确：mock loader 的通过不证明 HTTP、数据库或权限集成；Node 环境通过不证明浏览器；Vitest 语言测试通过不证明 Vue 组件渲染。每种证据只回答对应层。

## 120 秒讲述模板

> 异常边界只捕获能处理或能补上下文的错误，包装时用 cause 保留原因，stack 只作宿主相关诊断。调试先判断失败阶段，再用断点验证一个假设。Vitest 测试用 AAA 把夹具、操作和断言分开；预言必须来自独立规则，覆盖正常、边界和异常。红绿证据要求故意改坏实现时同一断言可靠变红。异步 Promise 必须 await；共享夹具和未恢复 mock 会破坏隔离；vi.fn 替换外部函数端口，而不是复制内部算法。不应由本章解决的反例是真实浏览器 E2E 或服务端状态机授权。

## 独立练习

1. 为三条状态数据手算 expected，再写实现；
2. 分别注入总数加一、错误 expected，比较失败证据；
3. 写 `toThrow` 与 `rejects` 各一个，解释函数包装差异；
4. 忘记 await 一次，保存 Vitest 4 的失败提示，再修复；
5. 让两个测试共享数组，证明顺序泄漏，再改夹具工厂；
6. 用 `vi.fn` 替换 loader，断言返回与调用；
7. 包装 loader 错误并断言 `cause` 身份；
8. 加 `expect.hasAssertions()` 暴露沉默 catch；
9. 在断言前设断点，预测每个局部值；
10. 说明哪些结果仍需浏览器、组件或集成测试。

## 官方一手资料

以下页面于 **2026-07-17** 核对：

- [Vitest Getting Started](https://vitest.dev/guide/)：当前文档版本、Node 要求、安装与 `vitest run`；
- [Vitest Writing Tests](https://vitest.dev/guide/learn/writing-tests.html)：suite、测试文件、失败 diff、参数化与收集；
- [Vitest expect API](https://vitest.dev/api/expect)：matchers、`rejects/resolves` 与 assertion count；
- [Vitest vi API](https://vitest.dev/api/vi)：`vi.fn`、spy 和恢复语义；
- [ECMAScript 2026：Fundamental Objects / Error Objects](https://tc39.es/ecma262/2026/multipage/fundamental-objects.html#sec-error-objects)：Error 对象与 cause 相关语言语义；
- [Node.js Releases](https://nodejs.org/en/about/previous-releases)：Node 24 LTS 支持通道。

当前文档与锁定资产版本必须分别记录；官方页面不能替代实际 verifier 输出。
