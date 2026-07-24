---
schema_version: 2
edition: 2026.2-draft
id: ch.js.dom-mutation
title: DOM 树、查询、创建、更新与删除
responsibility: 把已知 HTML 结构映射为 DOM 节点查询和最小变更，区分属性、property、文本与 HTML 注入边界，不在本章处理事件传播。
volume: '08'
order: 10
level: L1-L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.dom-mutation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.collections
- ch.web.semantic-html
version_surfaces:
- browser
- browser-devtools
- html-living-standard
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“DOM 树、查询、创建、更新与删除”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-dom-tree-query
  - js-dom-safe-mutation
  covers_topics:
  - dom.node-element-tree
  - dom.query-selector
  - dom.traversal
  - dom.live-static-collection
  - dom.create-append-remove
  - dom.attribute-property
  - dom.text-content
  - dom.innerhtml-risk
  - html.landmark-elements
  uses_capabilities:
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从结构化数据安全创建、更新和删除一组语义工单节点；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-dom-tree-query
  - js-dom-safe-mutation
  covers_topics:
  - dom.node-element-tree
  - dom.query-selector
  - dom.traversal
  - dom.live-static-collection
  - dom.create-append-remove
  - dom.attribute-property
  - dom.text-content
  - dom.innerhtml-risk
  - html.landmark-elements
  uses_capabilities:
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: dom-state-table-browser-inspection-mutation-assertions
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误选择器、attribute/property 混淆或 innerHTML 注入造成的状态错误”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-dom-tree-query
  - js-dom-safe-mutation
  covers_topics:
  - dom.node-element-tree
  - dom.query-selector
  - dom.traversal
  - dom.live-static-collection
  - dom.create-append-remove
  - dom.attribute-property
  - dom.text-content
  - dom.innerhtml-risk
  - html.landmark-elements
  uses_capabilities:
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# DOM 树、查询、创建、更新与删除

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《数组、对象、Map、Set 与不可变更新》](ch.js.collections.md)：节点列表、数据映射和批量更新需要集合迭代与不可变输入边界。
- [《语义 HTML、文档结构与元数据》](../../volume-07-web-platform/chapters/ch.web.semantic-html.md)：DOM 变更必须保持正确的文档结构和原生元素语义。
<!-- END GENERATED LEARNING PREREQUISITES -->

HTML 源码经过解析后成为节点树；JavaScript 查询和修改的是当前 DOM，不是源文件字符串。选择器少一个 `#` 可能得到 `null`，循环读取 live collection 时删除节点可能跳项，把 `checked="false"` 当作 false 会得到相反状态，而把工单描述拼进 `innerHTML` 可能把数据解释为标签。DOM 代码的可靠性来自结构预言：每次操作后，节点数量、顺序、文本、属性/property 与语义父子关系都必须可检查。

本章只处理已知结构上的查询、遍历、创建、更新与删除。事件传播、表单提交、异步请求和框架虚拟 DOM 留给后续章节。FactoryCare DOM 是服务端快照的展示，不决定工单能否迁移状态。

## 完成定义与 canonical 预言

你要能交出：

1. 在 120 秒内说明 Node/Element 树、选择器、遍历、live/static 集合、创建/插入/删除、attribute/property、`textContent` 与 `innerHTML` 风险；
2. 从结构化数据建立语义工单列表，更新指定工单、删除指定工单，并保存操作前后 DOM 状态表；
3. 对 selector drift、布尔 attribute/property 混淆、`innerHTML` 注入和语义父子破坏定位首个可信证据；
4. 在固定浏览器 DevTools 中核对实际 DOM，并把模拟环境与真实浏览器证据分开。

canonical T1 预言是：**给定初始 DOM 和操作序列，节点数量、顺序、文本、属性和语义结构与预期快照一致。** “源码看着对”不够，因为 parser 与脚本可能改变树；“截图看着对”也不够，因为错误标签和隐藏注入节点可能样式相同。

## HTML 源码、DOM 与渲染不是同一层

考虑：

```html
<main>
  <section aria-labelledby="queue-title">
    <h2 id="queue-title">待处理工单</h2>
    <ul id="work-order-list"></ul>
  </section>
</main>
```

HTML parser 创建 `Document`、元素节点、文本节点等对象。DOM 展示当前节点关系；CSSOM 与布局/绘制是其他层。修改 `textContent` 会改变 DOM，浏览器随后可能重新计算样式和布局，但本章不把像素渲染当作 DOM 本身。

### Node、Element 与 Text

`Node` 是共同基础接口，`Element` 是元素节点接口，文本由 `Text` 节点表示。`document.querySelector` 返回 `Element | null`；`element.childNodes` 可包含文本/注释，`element.children` 只含元素。缩进换行也可能形成文本节点：

```js
// children 用于检查 ul 的 li 元素；childNodes 还会看到空白文本。
const list = document.querySelector("#work-order-list");
console.log(list.children.length);
console.log(list.childNodes.length);
```

不要因为 `childNodes[0]` 是文本就删除所有文本节点；先明确你要遍历的是元素还是所有节点。

## 查询：选择器是结构合同

`querySelector(selector)` 返回第一个匹配元素或 `null`；`querySelectorAll(selector)` 返回所有匹配元素的静态 `NodeList`：

```js
// 选择器来自页面固定合同，不由任意用户字符串拼接。
const list = document.querySelector("#work-order-list");
if (!list) {
  throw new Error("work-order list root is missing");
}

const items = list.querySelectorAll(":scope > li[data-work-order-id]");
```

若根节点必须存在，立即抛带职责的错误，比稍后 `Cannot read properties of null` 更可信。可选节点则显式处理 `null`，不要用可选链让必要更新静默消失。

### 查询范围缩小

先取功能根，再在根内查询，避免页面其他同名 class 被误选：

```js
// status 查询被限制在目标 item，防止更新另一个卡片的同名元素。
const status = item.querySelector("[data-field='status']");
```

ID 应在文档中唯一；class 适合一组元素；`data-*` 适合脚本需要的应用元数据。不要用可变展示文本或 CSS 布局层级作为业务身份。

### 动态值与 CSS 选择器

把任意 ID 直接拼进属性选择器会遇到引号、反斜杠等选择器语法。可以使用 `CSS.escape` 生成 CSS 标识符，或先取固定 `[data-work-order-id]` 集合后按 `dataset.workOrderId` 精确比较：

```js
// findWorkOrderItem 不把不可信 ID 解释成选择器语法。
function findWorkOrderItem(list, id) {
  return [...list.querySelectorAll("[data-work-order-id]")]
    .find((item) => item.dataset.workOrderId === id);
}
```

选择器转义解决语法边界，不是权限校验。

## 遍历：从已知节点沿关系移动

常用元素关系：

- `parentElement`：元素父节点或 `null`；
- `children`、`firstElementChild`、`lastElementChild`；
- `previousElementSibling`、`nextElementSibling`；
- `closest(selector)`：自身或最近祖先匹配；
- `matches(selector)`：当前元素是否匹配。

```js
// closest 用于从已知后代回到最近工单项；事件目标留到下一章。
const item = statusNode.closest("li[data-work-order-id]");
```

遍历应从已验证根开始。连续写 `node.parentElement.parentElement` 把代码绑死在包装层数；若语义目标是最近列表项，`closest` 更能表达合同。

## live collection 与 static NodeList

这是删除循环最常见的边界。

`querySelectorAll` 返回静态快照：之后 DOM 变化不会自动改变该 `NodeList`。`element.children` 和 `getElementsByClassName` 返回的集合通常是 live，会随树变化：

```js
const staticItems = list.querySelectorAll("li");
const liveItems = list.children;

list.append(document.createElement("li"));
console.log(staticItems.length); // 查询时的长度
console.log(liveItems.length);   // 当前长度
```

对 live collection 正向按索引删除会跳过：

```js
// 错误：删除索引 0 后，原索引 1 移到 0，而循环进入 1。
for (let index = 0; index < list.children.length; index += 1) {
  list.children[index].remove();
}
```

清空已知容器用 `replaceChildren()`；筛选删除可先 `[...list.children]` 快照再遍历，或逆序。不要死记“NodeList 都静态”或“HTMLCollection 都 live”，查看具体 API 合同。

## 创建节点：数据到结构的显式映射

创建一个列表项：

```js
// createWorkOrderItem 把结构化字段映射为固定语义节点，用户文本不进入 HTML parser。
function createWorkOrderItem(document, workOrder) {
  const item = document.createElement("li");
  item.dataset.workOrderId = workOrder.id;

  const article = document.createElement("article");
  const heading = document.createElement("h3");
  heading.textContent = workOrder.title;

  const status = document.createElement("p");
  status.dataset.field = "status";
  status.textContent = `状态：${workOrder.status}`;

  article.append(heading, status);
  item.append(article);
  return item;
}
```

映射一眼可查：数组元素 → `li`，一份独立工单摘要 → `article`，标题 → `h3`，状态 → `p`。class 和 data 属性用于样式/脚本，不替代 `li/article/h3` 语义。

### DocumentFragment 批量组装

```js
// fragment 是离线容器；append 到 list 时其子节点被移动，fragment 变空。
const fragment = document.createDocumentFragment();
for (const workOrder of workOrders) {
  fragment.append(createWorkOrderItem(document, workOrder));
}
list.replaceChildren(fragment);
```

Fragment 有助于集中一次结构替换和保持顺序，但不要声称它必然解决所有性能问题；实际布局成本需性能工具测量。`replaceChildren` 表达“结果集合完全由当前数据决定”，增量更新则应只替换目标文本/属性。

## append、prepend、before、after、replaceWith 与 remove

这些现代方法操作现有节点：

- `append`：在末尾加入字符串或节点；
- `prepend`：在开头加入；
- `before/after`：相对当前节点插入；
- `replaceWith`：替换当前节点；
- `replaceChildren`：替换全部子节点；
- `remove`：从父节点移除当前节点。

同一个节点 append 到新父节点会移动，不会自动复制。需要副本时 `cloneNode`，但深复制不会复制 `addEventListener` 注册的监听器，也可能复制重复 ID；本章不以克隆替代明确创建。

## 最小更新：保留未变节点身份

全量 `replaceChildren` 简单，适合初次渲染；更新一个状态时只改目标文本和数据属性：

```js
// updateWorkOrderStatus 保留 li/article/heading 身份，只同步两个受影响位置。
function updateWorkOrderStatus(list, id, nextStatus) {
  const item = findWorkOrderItem(list, id);
  if (!item) {
    throw new Error(`work order item not found: ${id}`);
  }

  item.dataset.status = nextStatus;
  const status = item.querySelector("[data-field='status']");
  status.textContent = `状态：${nextStatus}`;
}
```

最小更新让焦点、选择、滚动和后续监听器更容易保持，但必须同步所有由该字段派生的位置。DOM 不能成为数据源真相：更新函数同时接收明确状态，应用数据层仍需同步。

## textContent：把输入当文本

`textContent` 把字符串放入文本节点语义，不会把 `<img>` 解析成元素：

```js
// 即使 title 含尖括号，DOM 中也只出现文本。
heading.textContent = workOrder.title;
```

这不是“清洗 HTML”；它是选择不解释 HTML 的安全 sink。读取 `textContent` 会组合后代文本，设置它会替换全部子节点；若元素包含图标/链接等结构，不要用 `textContent` 覆盖整个容器，只更新专用文本节点。

`innerText` 与渲染/可见性、样式计算关系更紧，行为与 `textContent` 不同；数据映射主线用 `textContent`，实际可见文本验证仍需浏览器。

## innerHTML：进入 HTML parser 的高风险边界

`innerHTML` 把字符串解析为 HTML 片段。若字符串含用户、API 或数据库数据，就可能创建意外元素、属性与可执行上下文：

```js
// 禁止：title 被当成标记，而不是纯文本。
list.innerHTML = `<li><h3>${workOrder.title}</h3></li>`;
```

即使某些 `script` 通过 `innerHTML` 插入时不立即执行，也不能推出安全；事件属性、URL、SVG/MathML、后续 DOM 使用等仍有风险。最稳妥主线是固定结构用 `createElement`，不可信值用 `textContent`/明确 property。

若产品确实允许富文本，需要成熟 sanitizer、严格允许列表、Content Security Policy/Trusted Types 等系统策略，并验证具体浏览器；这超出本章。不要手写正则“删除 script”就声称安全。

## attribute 与 property：初始标记和当前对象状态

HTML attribute 来自标记字符串；DOM property 是当前 JavaScript 对象上的值。许多会反射，但类型、时机和规则不同：

```js
const checkbox = document.createElement("input");
checkbox.type = "checkbox";
checkbox.checked = true;

console.log(checkbox.checked);                // true，布尔 property
console.log(checkbox.hasAttribute("checked")); // false，未设置内容 attribute
```

`checked` attribute 表示默认/初始选中；`checked` property 表示当前选中状态。用户交互会改 property，不一定改 attribute。`value` 与 `defaultValue` 也要区分。

### 布尔 attribute 看“是否存在”

```js
// 错误："false" 属性仍然存在，因此布尔 attribute 仍为真。
checkbox.setAttribute("checked", "false");
console.log(checkbox.checked); // true
```

设置当前状态用 `checkbox.checked = false`；设置/删除 attribute 用 `toggleAttribute("checked", condition)` 或明确 remove。不要把字符串 `"false"` 当布尔 false。

### getAttribute/setAttribute 与 property

`getAttribute` 返回字符串或 `null`，`setAttribute` 接收字符串化值。标准 property 往往提供类型化/current state，如 `input.disabled` 布尔、`link.href` 解析后的 URL。选择基于合同：

- 需要原始 attribute 字符串/是否存在：attribute API；
- 需要当前控件状态：property；
- `aria-*` 没有统一跨版本 property 主线时用 attribute；
- `data-*` 可用 `dataset`，值仍是字符串。

### dataset 与身份

`data-work-order-id="WO-1"` 映射为 `element.dataset.workOrderId`。它适合 DOM 节点与应用身份的连接，不应保存 token、隐私或大型 JSON。DOM 可被用户和扩展修改，dataset 不是信任边界。

## 语义结构不能被脚本破坏

初始 HTML 用 `main > section > ul`，脚本必须让 `ul` 的直接业务子节点保持 `li`：

```js
// 错误：视觉上可通过 CSS 画成列表，但 div 不符合 ul 的预期内容模型。
const card = document.createElement("div");
list.append(card);
```

每个动态 `li` 内的 `article/h3/p` 使无 CSS 时仍有结构。脚本“动态生成”不是降低语义要求的理由。ARIA 不能把任意 div 汤自动变成良好 HTML；先使用原生元素。

## 空状态与状态提示

空列表可清空 `ul`，再显示列表外固定提示：

```html
<p id="board-status" aria-live="polite" hidden></p>
<ul id="work-order-list"></ul>
```

```js
// hidden property 与内容一起同步；事件何时触发留到后续章节。
status.hidden = workOrders.length !== 0;
status.textContent = workOrders.length === 0 ? "暂无工单。" : "";
```

`aria-live` 的真实播报需浏览器/辅助技术验证；DOM attribute 存在不证明用户体验。本章只检查节点和 attribute 状态。

## 删除与更新操作序列

预先写状态表：

| 步骤 | 操作 | count | order | 文本/属性 | 语义 |
| --- | --- | ---: | --- | --- | --- |
| S0 | 初始空壳 | 0 | 空 | status 显示空态 | `main>section>ul` |
| S1 | 渲染 WO-1/2/3 | 3 | 1>2>3 | 标题按纯文本 | ul 直接子项全 li |
| S2 | WO-2 状态更新 | 3 | 不变 | `IN_PROGRESS` + dataset | 节点身份不变 |
| S3 | 删除 WO-1 | 2 | 2>3 | WO-1 不可查 | 结构仍合法 |
| S4 | 全部删除 | 0 | 空 | 空态显示 | 固定 landmark 保留 |

实现：

```js
// removeWorkOrder 只移除匹配业务身份的 li，未找到时返回 false。
function removeWorkOrder(list, id) {
  const item = findWorkOrderItem(list, id);
  if (!item) {
    return false;
  }
  item.remove();
  return true;
}
```

返回 false 使调用者区分“已删除”和“本来不存在”。幂等策略属于函数合同，不能靠 DOM 最终看起来一样猜测。

## 浏览器 DevTools 证据

真实浏览器步骤：

1. 记录浏览器产品、完整版本、OS；
2. 在 Elements/DOM 面板定位 `#work-order-list`；
3. 操作前保存结构、节点数和关键 property；
4. 运行渲染/更新/删除；
5. 检查直接子节点、文本节点、attributes、`$0.checked` 等 property；
6. 搜索是否出现 `img/script/onerror` 等意外节点；
7. 查看 Accessibility 面板，但不把它等同读屏器实测；
8. 保存截图与控制台断言。

`view-source:` 展示响应源码，不展示脚本后的 DOM；Elements 面板展示当前 DOM。两者对不同问题负责。

## 自动模拟与真实浏览器边界

配套资产在 Node 中用 happy-dom 17.6.3 建立可重复模拟，验证选择器、节点树、`textContent`、attribute/property 和顺序。它不是 Chrome/Safari/Firefox，也不做真实布局、可访问树、CSP、Trusted Types 或完整 parser 兼容验证。

因此模拟绿灯只算自动化子证据；canonical 的 `browser-inspection` 仍需真实 evergreen 浏览器。公开报告必须写“真实浏览器未运行”而非省略。

## 四类故障的首个可信证据

### selector drift

现象：代码查 `.work-order-list`，HTML 只有 `#work-order-list`。首证据是固定根查询返回 `null`，而不是后续 property TypeError。修复选择器或建立稳定 `data-testid` 合同后，重跑同一状态表。

### attribute/property 混淆

现象：`setAttribute("checked", "false")` 仍选中，或用户修改 property 后读取 attribute 得到旧初始值。首证据是 `hasAttribute` 与 `checked` 同时打印显示差异。修复按“初始标记还是当前状态”选择接口。

### unsafe innerHTML injection

现象：标题 `<img data-injected>` 变成真实 img。首证据是输入进入 `innerHTML` sink，随后 `querySelector("[data-injected]")` 非空。修复用固定节点 + `textContent`；残余风险包括其他 HTML sink 与 URL attribute。

### semantic-dom-breakage

现象：ul 直接出现 div，标题级别错乱，更新删除了固定 section。首证据是直接子元素 tagName/landmark 快照偏离。修复创建正确元素和缩小替换范围；真实可访问树仍需浏览器检查。

## FactoryCare 权威边界

DOM 节点只显示工单快照。把 `data-status` 改成 `CLOSED` 不会、也不应关闭服务端工单。合法迁移仍由 Java 校验当前状态、角色/租户、原因/附件、审批、版本、SLA、审计和事件。DOM 还可能被用户 DevTools 任意修改，因此绝不能作为授权或持久化依据。

描述等文本可能来自用户，必须用文本 sink；租户数据隔离必须在服务端完成，前端隐藏节点不是权限。删除 DOM 节点只改变页面，不代表删除数据。

## 120 秒讲述模板

> HTML 解析后形成 DOM 节点树；Element 是 Node 的一种，children 只看元素而 childNodes 还含文本。querySelector 返回首个或 null，querySelectorAll 是静态 NodeList，而 children 常是 live collection。创建结构用 createElement，批量组装可用 DocumentFragment，更新一个字段应保留节点身份，删除用 remove。attribute 是标记字符串/存在性，property 是当前对象状态，checked=false 不能写成 checked="false"。不可信文本用 textContent；innerHTML 会进入 parser，可能注入节点。证据是固定操作序列后的数量、顺序、文本、属性/property 和语义父子关系。不应由本章解决的反例是事件传播或服务端状态迁移。

## 独立练习

1. 比较 `childNodes` 与 `children`；
2. 预测 live collection 删除跳项；
3. 为必要根节点写 null 失败边界；
4. 从三条数据创建 `li>article>h3+p`；
5. 输入含 `<img data-injected>`，证明只成为文本；
6. 比较 `checked` attribute、`defaultChecked` 与 property；
7. 更新 WO-2 并断言同一 li 身份；
8. 删除 WO-1 并检查顺序；
9. 注入错误 selector、innerHTML、div 子项并保存红灯；
10. 在真实浏览器核对 DOM，单独记录模拟未覆盖项。

## 官方一手资料

以下页面于 **2026-07-17** 核对：

- [WHATWG DOM Standard](https://dom.spec.whatwg.org/)：节点、选择器、遍历、集合与变更 API；
- [WHATWG HTML：Dynamic markup insertion](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html)：`innerHTML` 等动态标记插入语义；
- [WHATWG HTML：Common DOM interfaces](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html)：`dataset` 等 HTML DOM 接口；
- [WHATWG HTML：Form control infrastructure](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html)：控件当前值与相关 property；
- [Chrome DevTools：View and change the DOM](https://developer.chrome.com/docs/devtools/dom/)：真实浏览器 DOM 检查入口。

Living Standard 会持续更新；页面核对日期不能替代提交时的浏览器版本与实际观察。
