# 第 24 周：DOM、事件循环、Promise、Fetch、取消与浏览器安全

## 定位

本周学习 JavaScript 在浏览器里如何与页面、任务队列、网络、存储和生命周期协作。目标是能解释并修复请求竞态、重复监听、卸载后更新、取消失效和安全边界；这些机制是 Vue 生命周期与 SSE 的前置。

时间预算：15—18 小时。使用 Week 22 的原生页面和 Week 23 的纯 JS 模块，不引入 Vue。

## 前置

- 掌握 JS 值、作用域、闭包、函数、对象、原型和 ESM；
- 能用 DevTools Elements/Sources/Network/Console 调试；
- FactoryCare API 有开发环境或可控 fake server；
- 理解所有浏览器/网络输入都不可信。

## 目标

- 读取/创建/修改 DOM 并保持语义和安全；
- 理解事件传播、默认行为、委托和监听器清理；
- 建立 call stack、task、microtask、render 的事件循环模型；
- 正确组合 Promise/async/await 并处理错误、并发和取消；
- 使用 Fetch/AbortController 处理 HTTP、超时、竞态和响应解析；
- 区分 Cookie、Storage、Cache 与内存状态；
- 理解同源、CORS、CSRF、XSS、CSP 和敏感数据边界；
- 为 FactoryCare 原生页面实现可取消、只展示最新结果的数据加载。

## 完整概念清单

### DOM 与渲染边界

- Document/Element/Node、query selector、创建/插入/删除/替换；
- attribute、property、dataset、classList、style；
- `textContent` 与 `innerHTML`，不可信内容禁止直接插 HTML；
- form control property 与 attribute 初始值差异；
- DocumentFragment/template 的用途；
- layout/style/paint/composite 高层过程和强制同步布局概念；
- MutationObserver/ResizeObserver/IntersectionObserver 了解，使用后需清理。

### 事件

- capture → target → bubble；
- `target` 与 `currentTarget`；
- `preventDefault`、`stopPropagation` 和滥用风险；
- 事件委托、动态列表和最近匹配元素；
- once/passive/signal listener options；
- input/change/submit/click/keyboard 语义；
- 自定义事件只用于清晰边界，不构造隐形全局总线；
- 重复注册、匿名函数无法移除和页面销毁后的资源泄漏。

### 事件循环

- JS 执行栈、run-to-completion；
- task/macrotask、microtask 和浏览器渲染机会；
- Promise continuation 是 microtask，timer 是后续 task；
- microtask starvation 和长任务阻塞 UI；
- async function 调用先同步执行到首个 await；
- `await` 暂停当前 async 函数，不阻塞整个线程；
- Web Worker 用于 CPU 工作概念，不用于直接 DOM；
- 先预测日志顺序，再在浏览器验证。

### Promise 与异步组合

- pending/fulfilled/rejected 和 settled 后不可改变；
- `then/catch/finally` 返回新 Promise；
- 错误传播、遗漏 await、unhandled rejection；
- 串行 await 与 `Promise.all/allSettled/race/any`；
- 并发不等于并行，Promise 不会自动取消底层工作；
- `finally` 负责收尾，不应无条件覆盖新请求的 loading；
- stale closure、out-of-order response 和 latest-wins/token 策略。

### Fetch 与取消

- URL、method、headers、body、credentials；
- Fetch 只在网络级失败 reject，HTTP 4xx/5xx 需检查 `response.ok`；
- JSON/文本/流只能消费一次，解析也会失败；
- AbortController/AbortSignal、取消原因和复用边界；
- 超时可用组合 signal 或显式 timer，并清理 timer；
- 取消不能保证服务端撤销已执行写操作；
- retry 只对合适的幂等/临时失败，带退避和上限；
- 请求 ID/当前 controller 防止旧请求收尾覆盖新状态。

### 浏览器状态与安全

- Cookie 自动随匹配请求发送；HttpOnly/Secure/SameSite；
- localStorage/sessionStorage 同步、可被页面 JS 读取，不存长期敏感 token；
- IndexedDB/Cache API/Service Worker 建立概念；
- same-origin 由 scheme/host/port 决定；
- CORS 是浏览器读取策略，不是服务器认证授权；
- CSRF 利用自动凭证，XSS 执行不可信脚本；
- CSP、输出编码、可信模板、依赖安全高层措施；
- URL/DOM/消息/文件/网络响应均是不可信输入。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| DOM/事件 | 3h | 筛选表单、委托、清理和 XSS 反例 |
| 事件循环预测 | 2h | 10 个日志顺序与长任务实验 |
| Promise 组合 | 2—3h | 串并行、错误、allSettled 和 finally 竞态 |
| Fetch/Abort | 3h | 取消、超时、4xx/5xx、解析和最新请求 |
| 安全/存储 | 2h | Cookie/Storage/CORS/CSRF/XSS 威胁说明 |
| FactoryCare/复盘 | 3—5h | 原生数据页、故障恢复和独立改动 |

## FactoryCare 增量

- 原生 JS 实现工单列表的筛选、分页和 loading/empty/error/success；
- 快速切换状态时取消旧请求，并用请求身份防止旧 `finally` 清除新 loading；
- 组件化前用返回 cleanup 函数移除 listener/observer/timer；
- 服务端 401/403/404/409/422/500 映射为不同用户反馈；
- 不使用 `innerHTML` 展示工单描述；
- DevTools 证明取消、竞态、重复监听和 XSS 修复。

## 无 AI 任务（120 分钟）

实现 `loadWorkOrders(status)` 与原生筛选 UI：连续三次切换只展示最后一次；旧请求失败/完成不能覆盖新状态；卸载函数取消请求和监听；HTTP 错误与 JSON 解析错误分开。使用 fake fetch 测试乱序响应和取消。

## 验收

- 能预测 task/microtask/同步日志顺序；
- 能解释 Promise、网络请求、AbortController 和服务端写入不是同一层；
- 能修复旧请求 `finally` 覆盖新 loading 的竞态；
- 能说明 CORS、认证、CSRF 和 XSS 的区别；
- 原生页面资源可清理，乱序测试稳定通过；
- 能从 Network/Sources/Console 提供一次真实定位证据。

## 非目标

- 不学习 Vue 生命周期；
- 不深入浏览器引擎实现或手写 Promise；
- 不实现生产认证协议；
- 不用防抖代替取消/竞态正确性。
