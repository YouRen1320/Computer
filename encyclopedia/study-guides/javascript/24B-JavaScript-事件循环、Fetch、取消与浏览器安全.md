# JavaScript：事件循环、Fetch、取消与浏览器安全

## 1. JavaScript 一次只在一个调用栈上执行同步代码

浏览器主线程通常负责 JavaScript、部分 DOM、样式和布局工作。同步函数调用形成调用栈：

```js
function a() { b(); }
function b() { console.log('run'); }
a();
```

```text
push a → push b → console.log → pop b → pop a
```

只要当前栈没清空，用户输入和定时器回调就不能在同一线程插进来执行。

## 2. Web API 负责等待，事件循环安排回调

网络、计时器和用户事件由浏览器环境处理。完成后，相关回调不会直接打断当前代码，而是进入队列等待。

```text
调用栈执行同步代码
  → 浏览器在后台等待计时器/网络/事件
  → 完成后任务进入队列
  → 栈清空时事件循环取任务执行
```

所以 `setTimeout(fn, 0)` 表示最早在当前任务和已有优先工作完成后执行，不是立刻或精确 0 ms。

## 3. Task 和 Microtask 有不同处理时机

简化顺序：

```text
取一个 task 执行到调用栈为空
  → 清空 microtask queue
  → 浏览器可能渲染
  → 取下一个 task
```

常见 task：事件、计时器、部分消息；常见 microtask：Promise reaction、`queueMicrotask`、MutationObserver 回调。

```js
console.log('A');
setTimeout(() => console.log('B'), 0);
Promise.resolve().then(() => console.log('C'));
console.log('D');
// A D C B
```

## 4. Microtask 也可能饿死页面

每个 task 后浏览器会清空 microtask。如果 microtask 不断创建新 microtask，渲染和用户事件会长期得不到机会。

```js
function again() {
  queueMicrotask(again);
}
again();
```

异步不等于自动让出足够时间。大量 CPU 工作应切片、调度到后续任务，或移到 Web Worker。

## 5. Promise 表示未来完成或失败的结果

Promise 有三种状态：pending、fulfilled、rejected。状态一旦确定不能反转。

```js
fetch('/api/work-orders')
  .then(response => response.json())
  .then(data => render(data))
  .catch(error => showError(error));
```

每次 `then` 返回新的 Promise。回调返回普通值，下一步得到该值；返回 Promise，下一步等待它；抛异常，链进入拒绝。

## 6. async/await 是 Promise 流程的可读语法

```js
async function loadOrders() {
  const response = await fetch('/api/work-orders');
  const data = await response.json();
  return data;
}
```

async 函数总是返回 Promise。await 暂停当前 async 函数，把后续部分安排为 Promise reaction；它不会阻塞整个浏览器线程等待网络。

但 await 前后的同步计算仍在主线程，长循环仍会卡页面。

## 7. try/catch 能捕获 await 的拒绝

```js
try {
  const orders = await loadOrders();
  render(orders);
} catch (error) {
  showLoadError(error);
} finally {
  setLoading(false);
}
```

未 await 或未 return 的 Promise 可能逃出 try/catch：

```js
try {
  loadOrders(); // 拒绝发生在以后，当前 catch 捕不到
} catch { ... }
```

异步入口要明确谁负责等待和处理失败。

## 8. 并行和串行要按依赖关系选择

无依赖请求不要机械串行：

```js
const [orders, users] = await Promise.all([
  loadOrders(),
  loadUsers(),
]);
```

`Promise.all` 任一失败就整体拒绝，但其他操作不会因此自动取消。若要收集全部结果可用 `Promise.allSettled`。

第二个请求依赖第一个结果时才串行。并行过多也会压垮 API，需要并发上限。

## 9. Fetch 发出 HTTP 请求并返回 Response

```js
const response = await fetch('/api/work-orders', {
  headers: { Accept: 'application/json' },
});
```

Fetch Promise 通常在收到响应头后 fulfilled。`response` 包含：

- `status`、`ok`；
- headers；
- body 流；
- URL、redirect 等信息。

读取 JSON 是另一个异步步骤，body 通常只能消费一次。

## 10. HTTP 404/500 不会让 fetch 自动 reject

Fetch 通常只对网络层失败、取消等 reject；HTTP 错误仍是正常 Response：

```js
const response = await fetch(url);
if (!response.ok) {
  throw await toApiError(response);
}
```

如果忘记检查，404 JSON 可能被当成功数据渲染。应用应把状态码、错误 body 和 request ID 转成稳定错误模型。

## 11. 请求 body 和 Content-Type 必须一致

JSON 请求：

```js
await fetch('/api/work-orders', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
  body: JSON.stringify(input),
});
```

FormData 请求不要手动写 multipart boundary；浏览器会根据 FormData 设置正确 header。

GET/HEAD 通常不使用 body。不要把对象直接赋给 body 期待自动转 JSON。

## 12. Cookie 是否携带受 origin 和 credentials 影响

同源请求默认可按规则携带凭据。跨源请求若需要 Cookie，通常要配置：

```js
fetch(apiUrl, { credentials: 'include' });
```

服务端还必须允许具体 origin 和 credentials，并满足 Cookie SameSite/Secure 规则。

这不代表“设 include 就能登录”，也不应把 `Access-Control-Allow-Origin: *` 与凭据随意组合。

## 13. AbortController 用统一信号取消工作

```js
const controller = new AbortController();

fetch(url, { signal: controller.signal });

controller.abort();
```

取消后 Fetch 会以与 abort 相关的错误结束。取消表示调用者不再需要结果，可节省网络/解析并避免旧响应覆盖页面。

同一个 signal 也可传给多个 Fetch 或 addEventListener，统一清理。controller abort 后不能重新恢复，下一次操作要新建。

## 14. 超时可以通过 AbortSignal 表达

现代环境可使用超时 signal 或组合 signal；兼容边界需按目标浏览器查询。通用概念：

```text
用户取消信号
  + 超时信号
  → 任一个发生就终止请求
```

手动 setTimeout 时要在 finally 清理计时器。超时只说明客户端停止等待，不保证服务器没有执行写操作；写请求重试必须考虑幂等。

## 15. 搜索输入会产生响应竞态

用户依次输入 `m`、`mo`、`motor`：

```text
request(m)      慢 ───────────┐ 最后回来
request(mo)     中 ───────┐   │
request(motor)  快 ───┐   │   │
```

若谁最后返回就渲染谁，旧的 `m` 结果会覆盖最新 `motor`。

解决：

- 新请求时取消旧请求；
- 保存 sequence/request ID，只接受最新结果；
- 服务端也按合理条件响应。

取消是优化，sequence 判断才是最终 UI 所有权边界，因为取消可能来不及阻止响应。

## 16. Debounce 和 throttle 控制触发频率

- debounce：停止变化一段时间后执行，适合搜索输入；
- throttle：一段时间最多执行一次，适合滚动/拖动采样。

它们不自动解决网络响应乱序，也不替代服务端限流。组件销毁时要取消待执行计时器，避免页面离开后更新旧状态。

## 17. 重试前要判断操作和失败是否安全

适合重试：

- 临时网络错误；
- 可恢复 502/503/504；
- 服务端 429 并提供 Retry-After；
- 幂等 GET。

谨慎或不可直接重试：

- 非幂等 POST 且不知道服务端是否已执行；
- 400/401/403 等需改变输入或身份的失败；
- 业务冲突；
- 取消操作。

使用有限次数、指数退避和抖动。页面上给用户明确状态，不让请求无限后台循环。

## 18. 缓存由多层共同决定

浏览器内存/磁盘缓存、HTTP 共享缓存、Service Worker 和应用状态可能都保存数据。HTTP 主要通过：

- `Cache-Control`；
- `ETag` / `If-None-Match`；
- `Last-Modified`；
- `Vary`。

Fetch 的 cache 选项不能替代正确服务端 header。认证和租户化响应必须避免被共享给错误用户，`Vary` 与缓存键要包含必要维度。

## 19. Origin、site 和 URL 不是同一概念

Origin = scheme + host + port。Site 的浏览器安全定义与可注册域有关，SameSite Cookie 使用“site”概念，不等同 CORS 的 origin。

```text
https://app.example.com 与 https://api.example.com
  → 不同 origin
  → 可能属于同一个 site
```

这解释了为什么 CORS 和 SameSite/CSRF 不能用同一句规则推导。

## 20. 同源策略限制脚本读取其他源

它主要阻止一个 origin 的脚本随意读取另一个 origin 的敏感响应。某些跨源请求仍可能发送，例如图片、表单和导航。

因此：

- “攻击页面读不到响应”不代表请求没产生副作用；
- CORS 是服务端给浏览器的读取许可；
- CSRF 保护关注自动携带凭据的副作用；
- 服务端认证授权始终要执行。

## 21. CORS 预检是浏览器先询问权限

非简单跨源请求可能先发：

```http
OPTIONS /api/work-orders
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type
```

服务器响应允许的 origin、method、headers 和缓存时长。预检失败时真实请求通常不会发；真实请求失败时也要有相应 CORS header，否则 JavaScript 只能看到模糊网络错误。

curl 不执行浏览器 CORS 策略，所以 curl 成功不能证明页面跨源配置正确。

## 22. Cookie 登录需要 CSRF 防护

浏览器自动带 Cookie，恶意站点可能诱导修改请求。使用 Cookie 认证的状态修改应采用框架 CSRF Token、合理 SameSite 和正确方法语义。

前端常从页面/meta/Cookie（按框架模式）取得 CSRF Token，放入 header。具体名称和传递方式按后端框架合同，不要自己创造一个可预测固定字符串。

## 23. XSS 会在可信页面 origin 中执行攻击脚本

攻击输入若进入 `innerHTML`、脚本、URL 或属性错误上下文，就可能执行。攻击脚本继承当前页面 origin 的能力，可以读取页面数据、发已登录请求、篡改 UI。

防护：

- 文本用 `textContent`；
- 框架模板默认转义，不绕过；
- 富文本使用成熟 sanitizer；
- URL 只允许必要协议和来源；
- 避免 eval/字符串事件；
- 使用 CSP 作为额外层；
- Cookie 使用 HttpOnly 减少直接窃取。

HttpOnly 不能阻止脚本借页面发请求。

## 24. CSP 限制页面可以执行和加载什么

Content Security Policy 通过响应 header 指定脚本、样式、图片、连接等来源。严格 CSP 可使用 nonce/hash，减少注入脚本执行机会。

它是防御层，不是替代输出编码。宽泛 `unsafe-inline`、允许任意第三方域或随意追加来源会削弱价值。

部署前可先使用 report-only 收集违反情况，再逐步收紧，并防止报告带出敏感 URL。

## 25. 长任务会阻塞输入和渲染

若一段同步 JavaScript 连续运行很久：

- 点击和键盘事件等待；
- 动画掉帧；
- 浏览器无法及时绘制 loading；
- 用户感觉页面卡死。

可以：

- 减少工作量和算法复杂度；
- 分批处理并让出任务；
- 虚拟化长列表；
- 将纯 CPU 工作移入 Web Worker；
- 避免主线程解析超大 JSON。

`await Promise.resolve()` 只进入 microtask，未必给渲染机会；需要合适的调度边界。

## 26. Web Worker 用独立线程做 CPU 工作

Worker 没有普通页面 DOM 访问权限，通过 `postMessage` 传数据：

```text
主线程：发送计算输入
Worker：执行 CPU 密集处理
主线程：接收结果并更新 DOM
```

数据通常经过结构化克隆或 transferable 转移。Worker 不让低效算法自动变快，但能避免主线程交互被阻塞。

网络等待本身不需要 Worker；Fetch 已由浏览器异步处理。

## 27. 强制重排来自布局读写交错

```js
for (const row of rows) {
  row.style.width = '200px';        // 写
  console.log(row.offsetWidth);     // 读，可能强制布局
}
```

先批量读，再批量写；动画用 transform；大量更新合并到一帧。Performance 面板可看到 Layout、Recalculate Style 和 Long Task。

不要在不了解证据时为每次 DOM 改动手动优化，先量出瓶颈。

## 28. 内存泄漏常来自仍可到达的对象

垃圾回收只回收不可再到达的对象。常见保留链：

- 全局数组持续追加；
- 未移除的事件监听器；
- 未停止的计时器/观察器；
- 闭包持有已删除 DOM；
- 无上限 Map 缓存；
- 请求回调保留整个页面状态。

组件卸载时取消请求和清理资源；缓存有大小/TTL；用 Memory 工具比较快照，不以“页面越来越慢”直接断言泄漏。

## 29. 错误分为用户、业务、网络和程序错误

UI 处理应区分：

- 输入校验：指出字段如何修复；
- 401：需要登录或凭据刷新；
- 403：已认证但无权限；
- 409：版本/业务冲突，显示最新状态；
- 429：按提示退避；
- 5xx/网络：可重试或降级；
- 解析/代码错误：记录诊断并显示安全兜底。

不要对所有失败只显示“网络错误”，也不要把服务端堆栈直接呈现给用户。

## 30. 页面生命周期会影响请求和状态

用户可能在请求中导航离开、切后台、前进后退缓存恢复或网络变化。需要：

- 组件销毁取消不再需要的请求；
- 不在卸载后更新旧 DOM；
- 不依赖 unload 完成关键保存；
- 对草稿用明确持久化策略；
- 恢复页面时确认数据新鲜度。

`beforeunload` 会影响体验和缓存，且浏览器不保证在所有关闭场景执行。

## 31. DevTools Network 要看完整请求时序

排查 Fetch：

1. 请求是否发出；
2. 是否先有 OPTIONS；
3. method、URL、headers、credentials 是否正确；
4. 排队、DNS、连接、TLS、TTFB、下载各阶段；
5. 状态码和响应 body；
6. CORS/缓存/Service Worker 是否参与；
7. Initiator 是哪段代码；
8. 是否被 abort 或后来的响应覆盖。

控制台的一行 `Failed to fetch` 不足以定位原因。

## 32. 这篇的整体地图

```text
同步代码在调用栈执行
  → 浏览器把完成事件放入队列
  → task 后清空 microtask，再可能渲染
  → Promise / async 管理未来结果
  → Fetch 得到 HTTP Response，主动检查状态
  → Abort + request ID 处理取消与竞态
  → 重试、缓存、CORS、CSRF 按合同处理
  → 性能工具定位长任务、重排和内存保留
```

必须掌握：await 不会让 CPU 代码离开主线程；microtask 在下一个 task 前清空；Fetch 对 404/500 通常不 reject；取消不保证服务器未执行；CORS、CSRF、XSS 是不同边界；旧响应必须防止覆盖新状态。

Streams、Service Worker、IndexedDB 和浏览器调度 API 的完整细节属于“需要时查询”。
