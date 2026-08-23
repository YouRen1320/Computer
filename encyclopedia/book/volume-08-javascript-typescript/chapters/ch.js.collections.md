---
schema_version: 2
edition: 2026.2-draft
id: ch.js.collections
title: 数组、对象、Map、Set 与不可变更新
responsibility: 选择数组、普通对象、Map 和 Set 表达顺序、键值和唯一性，并用复制更新保护调用边界，不在本章教授原型继承。
volume: '08'
order: 7
level: L1-L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.collections.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.functions
version_surfaces:
- node-24-lts
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“数组、对象、Map、Set 与不可变更新”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-array-object-data
  - js-map-set-immutability
  covers_topics:
  - js.array-index-iteration
  - js.array-methods
  - js.object-literal
  - js.property-access
  - js.destructuring-spread
  - js.map-contract
  - js.set-contract
  - js.key-identity
  - js.shallow-copy-update
  - js.mutation-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现按状态分组和去重的工单数据转换且不修改输入集合；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-array-object-data
  - js-map-set-immutability
  covers_topics:
  - js.array-index-iteration
  - js.array-methods
  - js.object-literal
  - js.property-access
  - js.destructuring-spread
  - js.map-contract
  - js.set-contract
  - js.key-identity
  - js.shallow-copy-update
  - js.mutation-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: data-case-table-assertion-script-reference-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“误选集合结构、浅拷贝遗漏或原地修改导致的数据污染”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-array-object-data
  - js-map-set-immutability
  covers_topics:
  - js.array-index-iteration
  - js.array-methods
  - js.object-literal
  - js.property-access
  - js.destructuring-spread
  - js.map-contract
  - js.set-contract
  - js.key-identity
  - js.shallow-copy-update
  - js.mutation-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 数组、对象、Map、Set 与不可变更新

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《函数、参数、返回值与回调入口》](ch.js.functions.md)：数组回调、转换函数和数据更新边界依赖参数与返回值合同。
<!-- END GENERATED LEARNING PREREQUISITES -->

一批工单快照需要保持到达顺序；同一工单可能因重试重复出现；界面还要按状态分组，并把一个状态更新应用到视图副本，但绝不能反向污染原始响应。这里没有一种“万能集合”。数组表达有顺序的元素序列，普通对象表达一组命名字段，`Map` 表达键到值的动态对应，`Set` 表达成员唯一性。选错结构，程序即使能运行，也可能悄悄丢掉重复项、混淆键身份或改变调用者的数据。

本章建立一条可验证的主线：先声明数据需要保留什么，再选择集合；先声明谁拥有输入，再决定能否修改；最后用长度、顺序、唯一性和引用身份四类断言证明结果。我们只处理语言层数据结构和复制更新，不教授原型继承，也不把前端转换函数当作 FactoryCare 工单状态机的权威。

## 完成定义与 canonical 预言

学完后，你要能交出三类证据：

1. 在 120 秒内说明数组、普通对象、`Map`、`Set` 各自表达什么，浅复制能保护哪一层，并给出“不该用本章方案解决”的反例；
2. 从空目录实现按状态分组、按工单 ID 去重、应用更新且不修改输入的转换程序，保存输入、源码、命令和输出；
3. 面对误选集合结构、浅复制遗漏、原地修改三类注入故障，指出首个可信分歧，修复后重跑同一预言。

本章 T1 预言原文是：**空、重复、缺失键和更新场景的长度、顺序、唯一性与引用身份均符合预先声明的表格。** 因此“打印看起来差不多”不算通过。若输出顺序正确却修改了输入，失败；若长度正确却把两个不同对象误判为同一个键，失败；若新外层对象仍共享将被写入的嵌套对象，也失败。

## 先问语义，再选结构

| 需要表达的事实 | 默认结构 | 关键证据 | 常见误选 |
| --- | --- | --- | --- |
| 有先后次序、允许重复的一列工单 | `Array` | `length`、索引、迭代顺序 | 用对象的属性覆盖重复项 |
| 一个工单的固定命名字段 | 普通对象 | 字段名、`Object.hasOwn` | 为几个固定字段建立 `Map` |
| 运行时产生的键到分组的对应 | `Map` | `size`、`has/get/set`、键身份与迭代顺序 | 用普通对象承载对象键 |
| 已见过的唯一工单 ID | `Set` | `size`、`has/add`、首次出现顺序 | 每次都线性扫描数组 |
| 对输入执行更新但不改变调用者持有值 | 复制后更新 | 新旧引用不等、输入快照不变 | 对 `sort/splice/push` 或嵌套字段原地写入 |

“默认”不是绝对规则。若要序列化成 JSON，`Map` 和 `Set` 不能像普通对象与数组那样直接得到期望结构，需要显式转换；若键集合固定、字段有业务名称，普通对象通常更清楚。决定必须由数据合同驱动，而不是由方法数量或个人偏好驱动。

## 数组：有序、可重复、以索引访问

数组字面量建立一列元素：

```js
// snapshots 的职责是保存按到达顺序排列的工单快照。
const snapshots = [
  { id: "WO-101", status: "CREATED" },
  { id: "WO-102", status: "ASSIGNED" },
  { id: "WO-101", status: "CREATED" },
];

console.log(snapshots.length);    // 3
console.log(snapshots[0].id);     // WO-101
console.log(snapshots.at(-1).id); // WO-101
```

索引从零开始；`length` 对常规稠密数组表示末索引加一。数组允许重复，因此两条 `WO-101` 快照都在。不要把索引当稳定业务身份：过滤、排序、插入都会改变位置，工单身份应来自显式 `id`。

### “缺失元素”与值为 undefined 不完全相同

```js
// 这个例子专门对比空槽与显式 undefined，业务数据应避免制造稀疏数组。
const sparse = new Array(2);
const explicit = [undefined, undefined];

console.log(0 in sparse);   // false
console.log(0 in explicit); // true
```

两者读取 `array[0]` 都得到 `undefined`，但属性是否存在不同；一些数组方法会跳过空槽，另一些迭代方式会产生 `undefined`。业务转换优先构造稠密数组，不用 `delete array[index]` 留洞；删除元素时用返回新数组的过滤，或在明确拥有数组时用 `splice` 并承认它会修改原数组。

### 按值迭代、按索引迭代和回调方法

需要元素时用 `for...of`；确实需要索引时再用传统 `for` 或回调的第二参数：

```js
// 输出只读取元素，for...of 直接表达意图。
for (const snapshot of snapshots) {
  console.log(snapshot.id);
}

// map 把每个输入映射为一个输出，返回新外层数组。
const ids = snapshots.map((snapshot, index) => ({
  position: index,
  id: snapshot.id,
}));
```

`for...in` 枚举属性键，不是数组值迭代的默认工具；它还可能看到继承的可枚举属性，顺序语义也不是你想表达的“逐个元素”。数组主线使用 `for...of`、`map`、`filter`、`find`、`some`、`every` 和 `reduce`，并依据返回合同选择。

### 方法先分“修改接收者”和“返回结果”

| 方法 | 主要结果 | 是否修改原数组 |
| --- | --- | --- |
| `map` | 等长映射的新数组 | 否 |
| `filter` | 满足条件的新数组 | 否 |
| `slice` | 指定片段的浅复制 | 否 |
| `concat` | 拼接后的新数组 | 否 |
| `find` | 第一个匹配元素或 `undefined` | 否 |
| `push/pop/shift/unshift` | 修改长度并返回长度或元素 | 是 |
| `splice` | 删除/插入并返回被删元素 | 是 |
| `sort/reverse` | 排序/反转后的同一数组引用 | 是 |
| `toSorted/toReversed/toSpliced` | 对应操作的新数组 | 否 |

“返回新数组”只保证外层容器新建，不保证元素对象被深复制。`map(x => x)`、`slice()` 和 `[...input]` 的元素引用仍可能与输入相同。调试不可变更新必须同时检查外层引用和会被写入的嵌套引用。

### 回调应返回合同值

```js
// 箭头表达式体隐式返回布尔值，filter 才能作选择。
const created = snapshots.filter((snapshot) => snapshot.status === "CREATED");

// 花括号体必须显式 return；遗漏会使每次回调返回 undefined。
const labels = snapshots.map((snapshot) => {
  return `${snapshot.id}:${snapshot.status}`;
});
```

上一章的函数合同在这里直接成为集合合同：`map` 需要映射值，`filter` 需要可转为布尔的选择结果，`sort` 比较函数需要表达相对次序。不要在本应纯转换的回调里偷偷改输入对象。

## 普通对象：一组命名字段

对象字面量适合表达一个工单快照的命名属性：

```js
// workOrder 是一个记录状对象：字段名来自稳定的数据合同。
const workOrder = {
  id: "WO-101",
  status: "CREATED",
  priority: "HIGH",
  metadata: {
    source: "QR",
  },
};
```

普通对象的属性键是字符串或 Symbol。数字样式的键会转换为字符串；把对象作为方括号键也会先转换成属性键，多个对象通常都变成相同的 `"[object Object]"`，这正是动态对象键应选择 `Map` 的原因之一。

### 点访问、方括号访问与缺失

`workOrder.status` 适合源码中已知且是合法标识符的属性；`workOrder[fieldName]` 适合运行时确定的键。二者都可能在属性不存在时得到 `undefined`：

```js
// fieldName 来自受控白名单，而不是任意用户路径表达式。
const fieldName = "priority";
console.log(workOrder[fieldName]); // HIGH
console.log(workOrder.assignee);   // undefined
```

值为 `undefined` 与属性不存在仍是两个状态：

```js
// Object.hasOwn 只检查对象自身，不沿原型链寻找。
const record = { assignee: undefined };
console.log(Object.hasOwn(record, "assignee")); // true
console.log(Object.hasOwn(record, "reason"));   // false
```

若合同需要区分“调用者明确给了 undefined”和“完全没给”，用 `Object.hasOwn` 保存证据。`"status" in record` 会连继承属性一起判断，原型语义留到下一章；本章记录状数据默认关心自身字段。

### 计算属性名与对象不是字典万能替身

```js
// 受控字符串键可作为计算属性名。
const statusKey = "CREATED";
const counts = {
  [statusKey]: 2,
};
```

若状态键来自一组受控字符串，普通对象可以工作；但需要频繁增删、需要对象键、需要直接的 `size`，或需要避免继承属性参与时，`Map` 更明确。不要仅因 JSON 看起来方便就忽略真实键合同；也不要仅因 `Map` 新颖就把固定字段拆成 `get("id")`。

### 属性顺序不是结构选择的首要理由

现代 ECMAScript 对自身属性键的枚举顺序有规则，但整数索引样式键、其他字符串键和 Symbol 键分组处理。若业务明确依赖“工单到达顺序”，数组直接表达这个事实；若依赖“分组首次出现顺序”，`Map` 的迭代合同更直接。不要把普通对象偶然打印顺序当成队列。

## 解构、rest 与 spread：提取和浅复制

对象解构按属性名提取，数组解构按迭代位置提取：

```js
// 默认值只在属性值为 undefined 时启用，null 不会触发默认值。
const { id, status = "UNSPECIFIED", metadata: meta } = workOrder;
const [first, second] = snapshots;
```

对象 rest 收集未被显式提取的自身可枚举属性；spread 把来源的自身可枚举属性复制到新对象：

```js
// remaining 是新外层对象，但其中的嵌套引用仍可能共享。
const { id: ignoredId, ...remaining } = workOrder;

// 后出现的 status 覆盖前面的同名属性。
const updated = {
  ...workOrder,
  status: "ASSIGNED",
};
```

顺序是合同。`{ status: "ASSIGNED", ...workOrder }` 会被原有 `status` 覆盖，结果仍是 `CREATED`。合并外部数据前还要做字段白名单与运行时验证；spread 只是复制机制，不是输入校验、安全过滤或深合并策略。

### 浅复制的准确含义

```js
// 外层 updated 与 workOrder 不同，但 metadata 暂时仍是同一对象。
const updated = { ...workOrder, status: "ASSIGNED" };

console.log(updated !== workOrder);                    // true
console.log(updated.metadata === workOrder.metadata);  // true
```

若后续只读 `metadata`，共享引用未必构成错误；若新值会修改 `metadata.source`，就必须复制这一条路径：

```js
// 只复制将被更新的路径，保持其他未变值的结构共享。
const safeUpdated = {
  ...workOrder,
  status: "ASSIGNED",
  metadata: {
    ...workOrder.metadata,
    source: "DISPATCH",
  },
};
```

这叫 copy-on-write 风格的路径复制，不是递归深复制所有东西。无条件 JSON 往返会丢失 `undefined`、Symbol、函数、`Map`、`Set` 等值，还不能正确表达所有对象语义；`structuredClone` 支持的类型更多，但仍不是业务更新规则，也可能成本过高。先声明哪条路径要改，再复制那条路径。

## Map：动态键到值的明确对应

`Map` 的键和值都可以是任意 ECMAScript 语言值。`set` 写入，`get` 读取，`has` 区分“键不存在”和“值恰好是 undefined”，`size` 给出条目数：

```js
// groups 的数据源是 snapshots；键为规范化状态，值为保持到达顺序的数组。
const groups = new Map();

for (const snapshot of snapshots) {
  const key = snapshot.status ?? "UNSPECIFIED";
  const group = groups.get(key) ?? [];
  groups.set(key, [...group, snapshot]);
}

console.log(groups.size);
console.log(groups.has("CREATED"));
```

`Map` 迭代按条目插入顺序进行。已有键再次 `set` 会更新值但不会把键自动移到末尾；删除后重新插入才成为新的插入位置。分组数组内部的顺序则由你追加元素的方式决定。

可以把“第一次出现时建组，之后追加”写得更节制：

```js
// 变更只发生在函数新建的局部 Map/数组，输入 snapshots 没有被写入。
function groupByStatus(snapshots) {
  const groups = new Map();

  for (const snapshot of snapshots) {
    const key = snapshot.status ?? "UNSPECIFIED";
    if (!groups.has(key)) {
      groups.set(key, []);
    }
    groups.get(key).push(snapshot);
  }

  return groups;
}
```

这里 `push` 是允许的，因为数组由函数内部刚创建、尚未泄漏；“不可变”不是禁用所有变异，而是保护所有权边界。若内部容器不会在构建过程中被外部观察，局部变异通常简单高效。返回后是否允许调用者改它，需要另行声明。

### get 的 undefined 歧义

`map.get(key) === undefined` 不能单独证明键不存在，因为键可能显式映射到 `undefined`。需要区分时先 `has`：

```js
// has 保存键存在性的事实，get 返回其值。
if (updates.has("WO-101")) {
  const patch = updates.get("WO-101");
  console.log(patch);
}
```

## Set：成员唯一性和首次出现顺序

`Set` 保存唯一值。`add` 添加，`has` 查询，`delete` 删除，`size` 给出成员数：

```js
// seenIds 只记录已接纳的字符串身份，unique 保留首次出现顺序。
const seenIds = new Set();
const unique = [];

for (const snapshot of snapshots) {
  if (seenIds.has(snapshot.id)) {
    continue;
  }
  seenIds.add(snapshot.id);
  unique.push(snapshot);
}
```

这段合同是“按 ID 去重并保留第一次出现”。若业务要保留最后一次，应明确遍历或覆盖策略；若要合并重复快照，必须定义字段冲突规则。`Set` 只解决成员唯一性，不会替你决定“第一条、最后一条还是合并”。

对原始字符串、数字等值，`new Set(array)` 常用于去重：

```js
// 展开 Set 得到按首次插入顺序排列的新数组。
const uniqueIds = [...new Set(snapshots.map((snapshot) => snapshot.id))];
```

但 `new Set(arrayOfObjects)` 按对象身份去重，不会按 `id` 字段比较。两个内容相同的对象字面量仍是两个成员。

## 键身份：SameValueZero 与对象引用

`Map` 和 `Set` 对键/成员使用 SameValueZero 语义。对大多数原始值，它接近严格相等；关键边界是 `NaN` 与自身视为相同，`+0` 和 `-0` 视为相同。对象则按引用身份：

```js
// firstKey 与 secondKey 内容相同但身份不同。
const firstKey = { tenantId: "T-1" };
const secondKey = { tenantId: "T-1" };
const cache = new Map([[firstKey, "cached"]]);

console.log(cache.get(firstKey));  // cached
console.log(cache.get(secondKey)); // undefined

const values = new Set([NaN, NaN, +0, -0]);
console.log(values.size); // 2
```

若业务身份由多个字段组成，不要每次临时创建对象再期待 `Map` 认出“内容相同”。可选择稳定的规范化字符串键、嵌套 `Map`，或复用同一对象身份；规范化规则必须避免歧义。比如简单拼接 `tenantId + ":" + id` 只有在分隔符与转义规则明确时才安全。

普通对象则会把非 Symbol 键转换成字符串：

```js
// 两个对象键都通常转换成 "[object Object]"，后一次覆盖前一次。
const wrongIndex = {};
wrongIndex[firstKey] = "first";
wrongIndex[secondKey] = "second";
console.log(Object.keys(wrongIndex).length); // 1
```

这就是“误选集合结构”最早的可信证据：写入第二个不同身份键后，键数没有增长。不要等到界面少一条记录才猜测。

## 复制更新：先画所有权边界

把值标成三类有助于决定是否可修改：

- **借入输入**：调用者传入，函数只读；不得 `sort`、`splice`、改元素字段；
- **函数内新建**：尚未泄漏，可局部构建和修改；
- **返回结果**：交给调用者后，其后续可变性由 API 合同决定。

```js
// updates 是按工单 ID 提供的补丁；函数返回新数组、新工单和新 metadata。
function applyUpdates(input, updates) {
  return input.map((workOrder) => {
    const patch = updates.get(workOrder.id) ?? {};
    return {
      ...workOrder,
      ...patch,
      metadata: {
        ...workOrder.metadata,
        ...(patch.metadata ?? {}),
      },
    };
  });
}
```

这里每个输出工单都是新外层对象，`metadata` 也是新对象。若 `workOrder.metadata` 可能缺失，展开 `undefined` 在现代对象 spread 中不会复制属性，但为了合同清晰可写 `...(workOrder.metadata ?? {})`。补丁字段白名单、状态合法性、权限和乐观锁不由这个语言函数解决。

### Object.freeze 不是深冻结

`Object.freeze(object)` 防止该对象自身属性的添加、删除和重新赋值，但嵌套对象仍可变，除非逐层冻结。冻结还不能替代数据所有权设计；生产代码不应依赖“冻结后报错”作为唯一边界。测试夹具可浅冻结输入，配合严格模式尽早暴露写入。

### 引用身份断言比 JSON 对比多看一层

```js
// snapshot 保存值证据，引用断言保存所有权证据。
const before = JSON.stringify(input);
const result = applyUpdates(input, updates);

assert.equal(JSON.stringify(input), before);
assert.notStrictEqual(result, input);
assert.notStrictEqual(result[0], input[0]);
assert.notStrictEqual(result[0].metadata, input[0].metadata);
```

JSON 快照只能覆盖可序列化值，不能证明引用不共享；引用断言也不能证明字段值正确。两者互补。

## FactoryCare 转换：分组、去重、更新一次完成

下面的设计把每条证据分开保存：

```js
// buildCollectionView 只构造前端只读视图，不决定服务端状态迁移是否合法。
function buildCollectionView(input, updates = new Map()) {
  const updated = input.map((workOrder) => {
    const patch = updates.get(workOrder.id) ?? {};
    return {
      ...workOrder,
      ...patch,
      metadata: {
        ...(workOrder.metadata ?? {}),
        ...(patch.metadata ?? {}),
      },
    };
  });

  const byStatus = new Map();
  const seenIds = new Set();
  const unique = [];

  for (const workOrder of updated) {
    const statusKey = workOrder.status ?? "UNSPECIFIED";
    if (!byStatus.has(statusKey)) {
      byStatus.set(statusKey, []);
    }
    byStatus.get(statusKey).push(workOrder);

    if (!seenIds.has(workOrder.id)) {
      seenIds.add(workOrder.id);
      unique.push(workOrder);
    }
  }

  return { updated, byStatus, unique };
}
```

分组保留全部快照，去重视图保留同 ID 首次出现的更新后快照。这是两个不同输出，避免把“按状态计数”与“唯一工单列表”混为一个破坏信息的步骤。若 `id` 缺失，当前代码会把所有缺失 ID 当作同一个 `undefined` 成员；真实合同应在进入转换前验证 ID，或明确缺失记录的隔离策略。本章案例只把“缺失状态”归入 `UNSPECIFIED`，绝不暗示缺失身份可以安全接纳。

### 预先声明的数据案例表

| 案例 | 输入 | 分组长度/顺序 | 唯一性 | 引用身份 |
| --- | --- | --- | --- | --- |
| 空 | `[]` | `byStatus.size === 0` | `unique.length === 0` | 返回新 `updated` 数组 |
| 重复 ID | `WO-1, WO-2, WO-1` | 分组仍含 3 条且保持到达顺序 | 唯一列表为 `WO-1, WO-2` | 输入元素未写入 |
| 缺失 status | 一条无 `status` | 首次出现时建立 `UNSPECIFIED` 组 | 仍按 ID 判断 | 新结果对象保留其他字段 |
| 更新 | `updates` 含 `WO-2` 补丁 | 按更新后状态分组 | ID 策略不变 | 外层、工单、被更新嵌套路径都是新引用 |

案例表应在写实现前完成，否则测试容易照着错误实现抄预期。输出对象不需要每一处都深复制；只要明示哪些嵌套值可能共享，并确保任何后续写路径已复制。

## 三类故障的首个可信证据

### 1. 误选结构导致 duplicate-key-loss

反例把每个状态只映射到一条工单：

```js
// 错误：同状态第二条会覆盖第一条，普通对象这里只保存单值。
const byStatus = {};
for (const workOrder of input) {
  byStatus[workOrder.status] = workOrder;
}
```

第一个可信证据不是最终页面，而是处理第二条 `CREATED` 后，该组长度仍无法达到 2。修复可以把值改成数组；键为受控字符串时普通对象可用，若需要明确 `size/has` 与插入迭代，则用 `Map<string, WorkOrder[]>` 思维模型。残余风险是重复 ID 策略仍未定义，分组修复并不会自动完成去重。

### 2. 浅复制遗漏导致 reference-aliasing

```js
// 错误：只复制工单外层，metadata 仍与输入共享。
const updated = { ...input[0] };
updated.metadata.source = "MOBILE";
```

最早证据是 `updated.metadata === input[0].metadata` 为真；写入后输入快照变化只是后续结果。修复是复制将写入的 `metadata` 路径。残余风险是 `metadata` 内若还有数组或对象且会被修改，仍需继续复制对应路径。

### 3. 原地方法导致 input-mutation

```js
// 错误：sort 返回同一数组并改变调用者持有的顺序。
const sorted = input.sort((left, right) => left.id.localeCompare(right.id));
```

最早证据是 `sorted === input` 为真，随后输入索引顺序变化。修复可用 `input.toSorted(...)` 或 `[...input].sort(...)`；后者先复制外层再排序。残余风险是元素对象仍共享，排序安全不等于元素字段更新安全。

## 诊断顺序：从合同到最小分歧

1. 固定最小输入并保存变更前快照；
2. 写出期望长度、键顺序、组内顺序和唯一 ID 顺序；
3. 在每次插入/去重决策后检查 `size/length/has`；
4. 在写嵌套字段前检查新旧引用是否相同；
5. 检查调用了修改型还是非修改型数组方法；
6. 只修一个原因，重跑原案例表；
7. 记录残余风险，例如嵌套更深、缺失 ID 或未验证外部输入。

不要以增加 `console.log` 数量替代预言。日志展示值，断言表达“为什么这个值必须如此”。错误栈第一行也未必是根因：浅别名通常在更早的复制决策处形成，直到后续写入才显现。

## FactoryCare 边界：这不是状态机实现

本章可以对服务端返回的工单快照做展示分组、客户端去重和本地视图复制；不能判断 `CREATED → TRIAGED` 是否允许，不能绕过角色、租户、必填原因、版本、审批、SLA、审计与领域事件。FactoryCare 的唯一状态机在 Java 服务端，前端 `Map` 只是一份派生视图。

同样，复制更新不等于并发控制。两个浏览器都从版本 5 复制出版本 6 的对象，服务端仍必须用版本条件防止覆盖。`Object.freeze` 也不是权限或防篡改边界；运行在用户设备上的 JavaScript 不能成为授权依据。

## 环境、可复现命令与版本边界

教材版本面登记为 `node-24-lts`。截至 2026-07-17，Node.js 官方发布表把 v24 “Krypton”列为 LTS；本章使用的数组、对象、`Map`、`Set`、spread 与私有引用断言属于稳定 ECMAScript 核心。示例 verifier 只依赖 `node:assert/strict` 与 shell，不下载第三方包。

建议记录：

```bash
node --version
node --check src/collection-view.mjs
./verify.sh
```

Node 与浏览器可能以不同样式打印对象、`Map` 和错误栈，因此预言不比较 `console.log(map)` 的美化文本，而把键和值映射成稳定字符串。当前本机运行结果只能证明实际 Node 版本；未在浏览器执行就必须标“未验证”，不能用规范链接替代运行证据。

## 120 秒讲述模板

可以按“语义—边界—证据—反例”组织：

> 数组表达有序且可重复的序列；普通对象表达固定命名字段；Map 表达动态键值对应并保留条目插入顺序；Set 表达按 SameValueZero 判定的唯一成员。对象键在 Map/Set 中按引用身份，因此内容相同的两个对象不是同一键。spread、slice、map 等通常只建立浅层新容器，嵌套对象仍可能共享；更新哪条路径就复制哪条路径。我的证据是空、重复、缺失状态和更新案例的长度、顺序、唯一性、输入快照及引用断言。不应由本章解决的反例是服务端工单状态迁移与并发授权，它们需要领域状态机和版本控制。

若讲述只说“Set 去重、Map 更强”，缺少选择维度；若说“spread 就是不可变”，缺少浅层边界；若说“前端复制后就不会冲突”，越过系统边界。

## 自检与独立练习

在看 private solution 前完成：

1. 预测 `[undefined]` 与 `new Array(1)` 在 `0 in array`、`length`、`map` 回调次数上的差异；
2. 用三条重复状态数据证明“对象键到单值”会丢信息，再改为键到数组；
3. 证明两个内容相同对象作为 `Map` 键时 `size === 2`；
4. 实现保留最后一次重复 ID 的策略，并写出它与保留第一次在顺序上的差异；
5. 构造两层嵌套对象，证明只 spread 外层仍会污染输入；
6. 给输入做值快照与引用断言，分别说明二者能发现什么；
7. 用空、重复、缺失状态、更新四行案例表验收转换；
8. 注入三类故障，每次只修一个，并保存失败日志和修复后结果。

## 官方一手资料

以下页面于 **2026-07-17** 核对：

- [ECMAScript 2026：Indexed Collections](https://tc39.es/ecma262/2026/multipage/indexed-collections.html)：数组对象、`Array.prototype` 方法与迭代语义；
- [ECMAScript 2026：Keyed Collections](https://tc39.es/ecma262/2026/multipage/keyed-collections.html)：`Map`、`Set`、SameValueZero 与迭代合同；
- [ECMAScript 2026：Expressions](https://tc39.es/ecma262/2026/multipage/ecmascript-language-expressions.html)：数组/对象初始化器与 spread 相关运行语义；
- [Node.js Releases](https://nodejs.org/en/about/previous-releases)：v24 LTS 状态；
- [Node.js v24 assert 文档](https://nodejs.org/download/release/latest-v24.x/docs/api/assert.html)：资产所用严格断言接口。

规范描述语言语义，不替代项目案例验证；Node 发布表说明支持通道，不证明本机已经运行 Node 24。
