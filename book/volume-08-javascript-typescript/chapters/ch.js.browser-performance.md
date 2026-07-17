---
schema_version: 2
edition: 2026.2-draft
id: ch.js.browser-performance
title: 强制重排、任务阻塞、监听清理与内存边界
responsibility: 用浏览器时间线定位 DOM 读写抖动、长任务、重复监听和不可达对象保留，实施最小修复，不把所有慢响应归因于前端。
volume: '08'
order: 14
level: L2+
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.browser-performance.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.events-forms
- ch.js.event-loop
- ch.css.motion-compositing
version_surfaces:
- browser
- browser-devtools
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“强制重排、任务阻塞、监听清理与内存边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-render-performance
  - js-listener-memory
  covers_topics:
  - web.forced-layout
  - web.layout-thrashing
  - web.long-task
  - web.frame-budget
  - css.compositor-friendly-property
  - dom.listener-cleanup
  - js.timer-cleanup
  - js.detached-dom
  - js.memory-retention-path
  uses_capabilities:
  - web.javascript-dom
  - web.javascript-functions-closures
  - web.accessibility
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“强制重排、任务阻塞、监听清理与内存边界”构建可运行程序与测试：为一个会抖动和泄漏监听器的列表页建立性能基线并完成可证修复；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-render-performance
  - js-listener-memory
  covers_topics:
  - web.forced-layout
  - web.layout-thrashing
  - web.long-task
  - web.frame-budget
  - css.compositor-friendly-property
  - dom.listener-cleanup
  - js.timer-cleanup
  - js.detached-dom
  - js.memory-retention-path
  uses_capabilities:
  - web.javascript-dom
  - web.javascript-functions-closures
  - web.accessibility
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: performance-trace-heap-snapshot-before-after-budget
- id: diagnose
  kind: fault-diagnosis
  text: 面对“交错 DOM 读写、忘记移除监听器或 timer 捕获节点导致的卡顿与保留”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-render-performance
  - js-listener-memory
  covers_topics:
  - web.forced-layout
  - web.layout-thrashing
  - web.long-task
  - web.frame-budget
  - css.compositor-friendly-property
  - dom.listener-cleanup
  - js.timer-cleanup
  - js.detached-dom
  - js.memory-retention-path
  uses_capabilities:
  - web.javascript-dom
  - web.javascript-functions-closures
  - web.accessibility
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 强制重排、任务阻塞、监听清理与内存边界

“页面慢”不是一个诊断结论。一次点击迟钝，可能是主线程上有长任务，也可能是样式失效后同步读取几何信息触发了布局；滚动掉帧，可能来自每帧修改会参与布局或绘制的属性；页面反复进入后越来越慢，可能是同一监听器重复注册、timer 没有停止，或者已从文档移除的节点仍被闭包持有。网络排队、服务端处理、图片解码、设备降频和扩展程序也会产生相似体感。没有时间线、堆保留路径和同负载前后对照，就不能把责任推给某一层。

本章只做一件事：用浏览器性能时间线定位 DOM 读写抖动、长任务、重复监听和不可达对象保留，实施最小修复，并用相同交互负载证明预算改善且功能和无障碍行为不回退。它不教授通用微优化清单，不承诺某个 CSS 属性在所有设备上一定进入独立合成层，也不把开发机上的单次录制当生产用户分布。

## 完成定义与 canonical 预言

完成本章需要交出四类证据：

1. 在 120 秒内解释强制重排、布局抖动、长任务、帧预算、监听与 timer 清理、脱离文档的 DOM 以及内存保留路径；同时给出一个不应由本章方案解决的反例，例如服务端首字节等待。
2. 对一个列表页定义固定数据、固定入口、固定动作次数和明确观察窗口，保存优化前的 Performance trace 与 Memory 证据。
3. 只修复证据命中的第一处问题，重跑同一负载；比较长任务、Layout 次数或保留对象，并验证键盘操作、焦点、可访问名称和业务结果没有回退。
4. 注入交错 DOM 读写、遗漏 removeEventListener、未停止 timer 捕获节点三类故障，指出首个可信证据，修复后重跑原验证并记录残余风险。

canonical T1 预言是：**同一交互负载的优化前后 trace 显示长任务、layout 次数或保留对象按预算下降，功能与无障碍行为不回退。** “同一”意味着数据量、动作序列、浏览器大版本、视口、录制设置和主要环境约束可比；“按预算下降”意味着先写阈值再看结果，而不是结果出来后移动门槛。

配套 Node 资产提供确定性的读写阶段计数、监听与 timer 所有权台账。它们能证明算法是否把读写分批、资源是否成对释放，却不会执行真实浏览器布局、绘制、合成或垃圾回收。因此资产通过只是进入真实 DevTools 验收的前置证据，不替代 trace 与 heap snapshot。

## 先把“慢”改写成可回答的问题

性能调查从一个可证伪的问题开始，而不是从工具面板开始。下列信息缺一项，前后对照就容易失真：

- 用户动作：从列表页已稳定后开始，连续展开 40 行，还是从导航开始算？
- 输入：工单数量、字段长度、图片状态和筛选条件是否固定？
- 观察窗：只看点击到下一次绘制，还是看 10 秒连续滚动？
- 环境：浏览器版本、视口、CPU/网络节流、扩展程序、温度和电源状态是什么？
- 指标：最长主线程任务、Layout 事件次数、总布局时长、掉帧、监听数量，还是特定构造器的 retained size？
- 预算：例如交互窗口内不出现超过团队阈值的长任务，或相同脚本下 Layout 次数从每行一次降到每批一次。
- 正确性护栏：列表顺序、展开状态、焦点去向、按钮可访问名称和键盘路径必须保持。

一个合格假设可以写成：“在 Chrome 目标版本、400 行固定数据和 40 次展开脚本下，renderRows 在每行写入后读取 offsetHeight，导致录制中的 Layout 次数随行数近似增长；先读后写应把次数降到每批预算，同时展开结果与键盘焦点不变。”它同时指出疑似代码、首个证据、最小修复和反证条件。

“用户说卡”仍是重要入口，但不是根因证据。真实用户监控可告诉你分布和受影响群体，实验室 trace 可解释单次执行路径，代码级计数器可验证控制流；三者回答的问题不同。

## 从 DOM 变更到像素：不要把所有工作都叫重绘

浏览器接收 DOM、CSSOM 和脚本后，需要在适当时机完成样式计算、布局、绘制与合成等工作。具体管线、线程和面板名称属于浏览器实现与版本表面，不能把一张教学图当跨浏览器规范合同。诊断时仍可使用下面的因果模型：

1. 样式计算决定哪些规则作用于元素。
2. 布局根据约束求元素的几何位置和尺寸。
3. 绘制把背景、文字、边框和阴影等转成绘制指令或栅格工作。
4. 合成组合已有图层，常能在不重新布局的情况下改变最终位置或透明度。

一次修改不一定经过所有阶段。改变容器宽度通常会使后代几何失效；改变颜色通常不要求重新求几何但可能需要绘制；在满足实现条件时，transform 与 opacity 动画常能主要由合成处理。这里的“常”很重要：浏览器会依据图层、内存、内容和实现决策处理，代码不能要求“用了 transform 就必定零绘制”。Performance trace 才是目标页面上的证据。

合成友好属性不是无障碍豁免。视觉移动后，DOM 顺序、焦点顺序和辅助技术语义不会自动随 transform 改变。若用 transform 把第十项视觉移到第一项，却保留原 DOM/键盘顺序，就可能得到更平滑却更难用的界面。

## 强制布局：一次同步读为何会打断批处理

浏览器通常可以把多次 DOM/样式变更收集起来，在稍后的渲染机会统一处理。若脚本先使几何信息失效，随后立刻同步读取当前几何，浏览器为了返回正确值，可能必须提前完成样式计算或布局。DevTools 可能把这段工作呈现为 Layout、Recalculate Style、forced reflow 警告或相近名称；名称和归因 UI 会随版本改变。

常见模式是：

~~~js
// 数据源是 rows；循环中的写后读会要求每一轮都得到最新几何。
for (const row of rows) {
  row.style.width = nextWidth + "px";
  heights.push(row.offsetHeight);
}
~~~

offsetHeight、getBoundingClientRect、某些计算样式查询和滚动几何读取都可能需要最新布局，但是否真的触发强制布局取决于此前失效状态和浏览器实现。不能看到某个 API 名就判罪；要在时间线中展开对应调用，观察 Layout 是否位于脚本调用栈之下，以及源码位置是否与交错读写一致。

“强制”描述的是布局被同步查询提前要求，不等同于“布局永远不该发生”。页面首次呈现、窗口变化或内容变化都可能合法布局。优化目标通常是减少不必要的重复和关键交互中的同步阻塞，而不是追求 Layout 计数永远为零。

## 布局抖动：交错读写把一次批处理放大成多次

layout thrashing 的典型形状是写、读、写、读反复交错。每次写都可能使几何失效，每次读又迫使浏览器结清债务。列表越长，成本越明显：

~~~js
// 第一阶段只读取；快照成为后续映射的唯一几何数据源。
const heights = rows.map((row) => row.getBoundingClientRect().height);

// 第二阶段只写入；此处不再读取会依赖刚才写入结果的几何属性。
rows.forEach((row, index) => {
  row.style.transform = "translateY(" + heights[index] + "px)";
});
~~~

这段代码展示的是“读阶段与写阶段分离”的意图，不是可直接复制的虚拟列表算法。真实页面还要处理滚动容器、测量失效、字体加载、ResizeObserver 回调、可变高度和焦点。优化前先确认业务确实需要这些读写；删除无用读取往往比更复杂的调度器更可靠。

requestAnimationFrame 可以把写入安排到渲染机会之前，但它不会自动修复交错模式。把每一轮写后读原封不动放进同一个 rAF 回调，仍可能抖动。相反，明确的 measure 阶段收集只读快照、mutate 阶段应用只写变更，才建立可检查边界。跨帧拆分也要避免用户看到中间态。

### 最小诊断顺序

1. 用固定动作录制 Performance。
2. 在主线程找到占用最大的交互区间，不先猜源码。
3. 展开脚本与 Layout 事件，检查是否有 forced reflow 提示及其调用栈。
4. 回到命中行，列出该循环内所有会使样式/几何失效的写和所有几何读。
5. 先删除不需要的读；再尝试缓存稳定值或分离读写阶段。
6. 重跑相同动作，比较次数和持续时间；同时执行正确性与无障碍断言。

“把所有 offsetHeight 缓存起来”也可能错误。窗口变化、内容变化和字体加载后，旧高度可能失效。缓存必须有明确的生命周期与失效事件，否则只是把性能问题换成陈旧数据问题。

## 长任务与帧预算：阈值不是万能 SLA

主线程一次任务运行期间，同一线程上的输入处理、样式布局和脚本通常无法随意插入。任务越长，用户等待下一个响应或渲染机会的风险越高。W3C Long Tasks API 编辑草案目前以 50 毫秒作为长任务阈值，并允许通过 PerformanceObserver 观察 longtask 条目；该文档仍明确标为工作草案，浏览器支持、归因字段和隐私限制必须按目标版本验证。

50 毫秒不是“49 毫秒一定流畅”的保证，也不是业务 SLA。60Hz 显示器的一帧约 16.7 毫秒，但脚本只能使用其中一部分，且 90Hz、120Hz、后台标签、节能模式和浏览器自身工作都会改变可用窗口。可靠做法是：

- 用目标交互和目标设备分布定义预算；
- 在 trace 中区分脚本、样式、布局、绘制与其他工作；
- 把大循环按可中断边界分块，必要时在任务之间让出执行机会；
- 避免把必须原子完成的状态更新拆出可见中间态；
- 检查分块后总工作量是否反而增加，或者输入是否被旧任务继续覆盖。

下面的分块伪例只表达调度意图：

~~~js
// pendingOrders 是数据源；每批完成后让宿主获得处理后续工作的机会。
function processBatch(pendingOrders, start = 0) {
  const end = Math.min(start + 100, pendingOrders.length);
  for (let index = start; index < end; index += 1) {
    normalizeOrder(pendingOrders[index]);
  }
  if (end < pendingOrders.length) {
    setTimeout(() => processBatch(pendingOrders, end), 0);
  }
}
~~~

timer 不是精确调度器，也不保证下一帧之前运行。若任务与 UI 呈现相关，要按目标浏览器评估 rAF、宿主调度 API或 Worker；本章不把实验性 API 写成稳定依赖。若计算不需要 DOM 且耗时很大，Worker 可能是方案，但线程通信、复制成本和取消协议属于额外设计，不是“一行修复”。

## 监听器生命周期：注册者必须能说明谁来释放

addEventListener 会建立事件目标到回调的关系；回调闭包又可能引用组件状态和节点。问题不只是“监听器数量多”，而是生命周期失配：页面每次进入都注册一次，却没有在退出时以同一目标、同一事件类型和兼容的捕获选项移除；或者匿名函数导致清理时拿不到同一个回调引用。

~~~js
// mount 的副作用是注册一次监听；返回的 cleanup 拥有唯一释放责任。
function mountList(list, onActivate) {
  const handleClick = (event) => {
    const row = event.target.closest("[data-order-id]");
    if (row) onActivate(row.dataset.orderId);
  };

  list.addEventListener("click", handleClick);
  return () => list.removeEventListener("click", handleClick);
}
~~~

事件委托可以把逐行监听降为容器监听，但不能替代清理。容器本身若跨路由被保留，闭包仍可能保留旧状态。用 AbortSignal 统一取消监听在受支持浏览器中很实用，但仍要由清晰的生命周期调用 abort，并验证目标版本。

清理函数应满足幂等语义：执行一次完成释放，再执行不制造异常或新资源。组件挂载与卸载测试至少覆盖“进入、操作、退出、再次进入”，因为单次运行看不出重复注册。计数器可以验证 add 与 remove 的净差，真实堆快照则验证对象是否仍可达；两类证据不能互换。

## timer 清理：停止调度，也要断开捕获关系

setInterval、递归 setTimeout 和 rAF 都产生未来回调机会。回调若闭包捕获节点或大型数据，即使节点从文档移除，只要调度器仍引用回调，那条引用链就可能继续存在。清理至少包括：

- 保存句柄；
- 在卸载、取消或完成时调用对应 clear/cancel；
- 防止异步回调在清理后再次创建下一次 timer；
- 让回调不再把旧节点写回页面；
- 若同时有监听器、观察器和请求，建立一个统一而可审计的 cleanup。

~~~js
// startRefresh 的副作用是创建周期任务；stop 同时阻止再次调度。
function startRefresh(node, readStatus) {
  let stopped = false;
  let timerId;

  function tick() {
    if (stopped) return;
    node.textContent = readStatus();
    timerId = setTimeout(tick, 1000);
  }

  tick();
  return function stop() {
    stopped = true;
    clearTimeout(timerId);
  };
}
~~~

只 clear 当前 timer 但不设置 stopped，可能遇到正在执行的 tick 在清理后又排下一次。反过来只设置布尔值不清 timer，会让无用回调仍在未来被唤醒。准确策略取决于控制流，验证要覆盖清理与回调竞争的边界。

## detached DOM 与“不可达对象”的准确说法

节点从 document 树移除，不代表 JavaScript 世界已经无法到达它。数组、Map、缓存、监听回调、timer、Promise reaction、全局变量或开发者工具控制台都可能保留引用。DevTools 的 heap snapshot 会记录可达对象关系；被标为 detached 的节点提示它不在文档树中但仍被 JavaScript 引用，需要沿 retainers 查谁把它连回垃圾回收根。

“页面中看不见”不是泄漏证据，“堆里还有对象”也不是。垃圾回收时机不由业务代码精确控制，一次快照可能包含尚未回收但之后可释放的对象。更可信流程是：

1. 打开页面并建立稳定基线。
2. 执行固定次数的进入、创建、操作、退出。
3. 在一致条件下采集前后快照；不要在控制台变量里无意保留目标对象。
4. 按构造器或 detached 节点筛选，比较数量与 retained size。
5. 选择实例，沿 retainers 找到第一个由应用拥有、且生命周期不应存在的引用。
6. 修复拥有者的释放逻辑，再以同一循环重测。

shallow size 只表示对象自身大致占用，retained size 表示若该对象不可达可能随之释放的对象集合，解释时不能简单相加。快照本身也会影响内存与运行状态，绝对数值会受浏览器实现影响；最有用的是同环境、同动作、同筛选下的保留路径与增长趋势。

### 一个保留路径例子

假设退出列表后仍看到旧行节点：

    GC root
      → Window
      → refreshRegistry
      → timer callback
      → lexical environment
      → oldListNode
      → detached row descendants

第一可信证据不是“Detached HTMLDivElement 数量大”，而是 timer callback 的词法环境仍引用 oldListNode。最小修复应回到 refreshRegistry 的释放职责，停止 timer 并删除注册项；不应在节点上随意置空一批字段来掩盖路径。

## 一次可审计的 Performance trace 流程

Chrome DevTools Performance 面板的 UI 和类别会随版本改变，本章按 2026-07-17 可访问的官方文档描述概念流程，操作前应记录浏览器版本：

1. 关闭无关标签或至少记录它们，准备固定数据与动作脚本。
2. 在目标页面稳定后开始录制，执行一次短而可重复的交互，然后立即停止。
3. 先查看概览中主线程繁忙区间与帧，再在 Main 轨道选择最长或最可疑切片。
4. 展开事件调用树或自下而上视图，查找 Long task 标记、Layout、Recalculate Style 及源码归因。
5. 截图不能替代 trace 文件；保存原始 trace、浏览器版本、动作说明和代码版本。
6. 只做一个有因果依据的修复，重录并用同样窗口比较。

录制过长会引入噪声和巨大文件；录制过短可能漏掉稳态问题。CPU 节流适合放大实验室差异，但不能声称等于某一真实设备。若一次优化只在无节流桌面改善、在目标低端设备没有改善，应以目标群体证据为准。

DevTools 把超过阈值的任务标为长任务时，可以继续展开看内部函数；不要把整个红色三角归因于最上层业务函数，框架、扩展、垃圾回收和浏览器工作可能共同出现。首个可信应用证据通常是具体调用栈、时间占比和可重复触发条件的交集。

## 前后预算表：让结论可以被反驳

建议保存如下表格，数值由实际录制填入，不复制示例数字：

| 条件 | 优化前 | 预算 | 优化后 | 结论 |
| --- | ---: | ---: | ---: | --- |
| 40 次展开窗口内 Layout 次数 | 实测 | 团队阈值 | 实测 | 通过/失败 |
| 最长主线程任务 | 实测 ms | 目标阈值 | 实测 ms | 通过/失败 |
| 10 次进出后 detached row 增量 | 实测 | 目标阈值 | 实测 | 通过/失败 |
| click 监听净增量 | 实测 | 0 | 实测 | 通过/失败 |
| timer 净增量 | 实测 | 0 | 实测 | 通过/失败 |
| 键盘展开与焦点结果 | 记录 | 不回退 | 记录 | 通过/失败 |

若优化后 Layout 次数下降但最长任务上升，不能只宣布成功；需要回到用户目标判断哪个指标更接近风险。若性能改善却丢失 aria-expanded 更新，同样失败。预算门既包含性能，也包含行为。

对数值做多次录制并报告中位数或分布通常比挑最好一次可靠，但具体统计方案取决于团队测试基础设施。T1 练习至少保证固定输入、短窗口和原始记录；生产发布门应结合真实用户数据与自动化实验室测试。

## 功能和无障碍不回退是同一个验收门

性能修复常改变 DOM 批量更新、事件委托、视觉位置或异步分块，因此必须复查：

- 鼠标与键盘是否都能触发同一操作；
- 焦点是否仍停在逻辑位置，删除当前行后是否有明确去向；
- aria-expanded、可访问名称与错误信息是否随状态同步；
- DOM 顺序与视觉顺序是否一致；
- 快速连续输入是否被过期批次覆盖；
- cleanup 后重新进入是否只响应一次；
- reduced motion 偏好是否仍被尊重。

只比较截图不足以验证这些行为。至少要保存业务输出断言、键盘路径结果和可访问状态；若团队有自动化可访问性工具，它能发现部分规则问题，但不能替代人工键盘与读屏器验证。

## 故障注入：从首个证据到最小修复

### 故障一：交错 DOM 读写

注入方式：在每一行 style 写入后读取 offsetHeight。预期首证据：同一调用栈下重复 Layout 或 forced reflow 归因，次数随行数上升。修复：删除不必要读取，或建立只读快照后批量写入。重跑：Layout 次数或持续时间按预设预算下降，列表顺序、展开与焦点不变。

不要仅把读取移到一个辅助函数。调用栈更漂亮但执行顺序没有改变，性能不会因此改善。

### 故障二：遗漏监听清理

注入方式：每次 mount 都 addEventListener，unmount 不 remove。预期首证据：第二次进入一次点击触发两次，监听台账净增；堆中可能出现旧状态保留路径。修复：保存同一回调引用并在 cleanup 移除，或用目标版本支持的 AbortSignal 统一取消。重跑：多次进入仍每次只触发一次，净增为零。

“监听器面板显示多个条目”需要结合目标与生命周期解释；不同元素各有一个合法监听并不一定是泄漏。

### 故障三：timer 捕获已移除节点

注入方式：递归 timer 的闭包引用旧列表，退出时只移除节点。预期首证据：退出后 timer 继续执行，heap retainer 经回调词法环境到 detached 节点。修复：清 timer、防止再次调度、从所有权注册表删除。重跑：固定次数进出后 timer 净增为零，旧节点无应用保留路径。

### 故障四：性能改善造成行为回退

注入方式：用 transform 重排视觉列表，却不更新 DOM 顺序或焦点；或批量替换 innerHTML 丢失按钮语义。首证据不是 trace，而是键盘与可访问状态断言失败。修复必须同时满足预算与行为合同，不能用“更快”豁免正确性。

## 配套四类资产如何使用

每类资产都是独立目录，有自己的 package.json、pnpm-lock.yaml 和唯一 verify.sh：

- example：展示交错读写模型与分阶段模型的确定性对照，并验证监听、timer、功能和可访问名称护栏。
- lab：基线先通过，再依次注入布局抖动、监听遗漏、timer 保留与行为回退；验证脚本要求每个故障出现稳定标记。
- public exercise：保留一个写后读 TODO，初始验证应以 PERFORMANCE_BUDGET_EXERCISE 非零退出；学员分离阶段后同一脚本转绿。
- private solution：给出独立实现与完整断言，只用于阅卷，不应复制给学员。

这些资产不导入浏览器模拟库，因为常见 DOM 模拟器不会实现真实布局与渲染管线。模型中的 layoutCount 是由明确的“几何失效后读取”状态机生成，用于检查控制流；它不能作为 Chrome Layout 事件次数。真正完成 build outcome 时，仍需在目标页面保存 Performance trace 与 heap snapshot。

## FactoryCare 场景的责任边界

工单列表可能同时经历 API 慢、数据量大、前端渲染慢和设备资源紧张。调查顺序应按时间线分层：

- 请求在等待响应期间主线程空闲：先查网络、服务端和缓存边界，本章不负责。
- 响应后主线程被一个同步数据转换占满：长任务属于本章可定位范围；是否迁到 Worker 另行设计。
- 每插入一行就发生 Layout：检查交错 DOM 读写。
- 路由反复进出后一次点击执行多次：检查监听生命周期。
- 已退出页面仍周期写日志，heap 显示旧节点经 timer 保留：检查 timer 所有权。
- 滚动平滑但键盘顺序错：性能门未完成，必须修复无障碍回退。

服务器查询、数据库索引、HTTP 缓存、图片内容优化和框架级渲染架构都可能影响用户体验，但没有证据时不能借“前端性能”跨层扩张。本章的理想目标状态是：每项资源都有所有者和清理点，每次性能主张都有可复现负载、原始工件、预算与行为护栏。

## 120 秒口述模板

可以按“症状—机制—证据—修复—边界”组织：

“强制布局发生在脚本使几何失效后又同步索取最新几何，交错写读会把可批处理的布局放大成抖动；我用固定动作的 Performance trace 找 Layout 与调用栈，再以先读后写重跑预算。长任务表示主线程任务超过观察阈值，但 50 毫秒来自仍在演进的 Long Tasks 规范表面，不等于所有设备帧预算。监听器和 timer 必须由挂载者清理，否则闭包可能形成到 detached DOM 的保留路径；我用行为计数与 heap retainers 交叉验证。修复只有在相同负载下性能指标改善且键盘、焦点与可访问名称不回退才通过。服务端等待是反例，不能由 DOM 批处理修复。”

如果只能背术语而不能指出一个首证据、一个反证条件和一个层外反例，explain outcome 尚未完成。

## 版本表面与官方资料

本章的稳定因果模型是：同步几何读取可能要求结清失效的布局；长主线程任务会推迟同线程工作；可达引用阻止对象成为垃圾回收候选；资源生命周期要成对释放。下列细节属于版本表面：DevTools 面板名称与归因 UI、浏览器任务标记、Long Tasks API 支持与字段、合成策略、heap snapshot 分类和垃圾回收实现。

资料核对日期为 2026-07-17：

- Chrome DevTools 官方 Performance 文档：https://developer.chrome.com/docs/devtools/performance
- Chrome DevTools 官方内存问题指南：https://developer.chrome.com/docs/devtools/memory-problems
- Chrome DevTools 官方 heap snapshot 指南：https://developer.chrome.com/docs/devtools/memory-problems/heap-snapshots/
- W3C Long Tasks API 编辑草案：https://w3c.github.io/longtasks/

Chrome Performance 教程页面说明其截图与流程以特定 Chrome 版本为基础，使用不同版本时要以实际 UI 为准。Long Tasks 页面是编辑草案并明确仍在演进；使用 PerformanceObserver 前应检查目标浏览器的 supportedEntryTypes。资料支持机制与工具流程，不替代你对目标页面的录制。

## 有意不覆盖

本章有意不覆盖服务端性能、网络协议优化、图片编码、框架专属 profiler、Worker 完整协议、真实用户监控平台选型、浏览器引擎内部实现、垃圾回收算法调优和通用 CSS 动画教学。它也不保证“零 Layout”“零 detached 节点”或某个绝对毫秒值适用于所有用户。

没有为兼容旧浏览器保留一套降级实现；是否采用 AbortSignal、Long Tasks API 或新的调度 API，应由项目目标矩阵决定，基础清理和 trace 流程不依赖这些可选接口。完成本章的证据边界仍是 canonical 预言：相同负载下性能预算改善，功能与无障碍行为不回退，并保存能从首个证据追到修复的原始工件。
