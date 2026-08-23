# JavaScript：DOM、事件与表单

## 1. DOM 是浏览器把 HTML 表示成的对象树

浏览器解析 HTML 后，创建 Document Object Model（DOM）：

```html
<main>
  <h1>工单</h1>
  <ul><li>WO-42</li></ul>
</main>
```

概念树：

```text
document
  └── html
      └── body
          └── main
              ├── h1
              └── ul
                  └── li
```

JavaScript 操作的是这些 Node/Element 对象，不是直接修改原始 HTML 文件。

## 2. DOM、HTML 源码和当前页面状态可能不同

JavaScript 可以新增、删除和改属性；浏览器也会纠正不合法 HTML。因此 DevTools Elements 面板显示的是当前 DOM，不一定和服务器最初返回的文本完全一致。

表单输入还有属性与当前 property 的区别：用户修改 input 后，`input.value` 是当前值，而 HTML `value` attribute 更接近初始声明。

排查页面时要确认自己查看的是源码、DOM、JavaScript 状态还是最终视觉结果。

## 3. 查询元素应选择稳定边界

```js
const form = document.querySelector('#work-order-form');
const rows = document.querySelectorAll('[data-work-order-row]');
```

- `querySelector` 返回第一个匹配元素或 null；
- `querySelectorAll` 返回静态 NodeList；
- `getElementById` 按唯一 ID 查找。

查不到元素时不要直接调用方法：

```js
const form = document.querySelector('#work-order-form');
if (!form) {
  throw new Error('缺少 #work-order-form');
}
```

生产 UI 可选择温和降级，但开发时静默忽略会掩盖模板错误。

## 4. data-* 适合连接 DOM 与行为标识

```html
<button data-action="close" data-order-id="WO-42">关闭</button>
```

```js
button.dataset.action;  // 'close'
button.dataset.orderId; // 'WO-42'
```

data attribute 是字符串，不是可信权限信息。任何用户都能在 DevTools 修改 `data-role="admin"`，服务端不能据此授权。

行为选择器和样式 class 分开，重构样式时更不容易破坏脚本。

## 5. 创建节点比拼接 HTML 更安全清楚

```js
const item = document.createElement('li');
item.className = 'work-order-item';
item.textContent = order.title;
list.append(item);
```

`textContent` 把输入作为文本。若写：

```js
item.innerHTML = order.title;
```

不可信标题可能被解释为 HTML，造成 XSS。只有确实需要 HTML、来源可信或经过适合上下文的严格消毒时才用 `innerHTML`。

## 6. textContent、innerText 和 innerHTML 不相同

- `textContent`：节点中的文本内容，不按视觉布局计算；
- `innerText`：更接近用户看到的文本，可能触发布局计算；
- `innerHTML`：HTML 标记字符串，会解析成节点。

设置普通动态文字默认使用 `textContent`。读取可见文案才考虑 `innerText`，插入模板优先使用框架绑定、`template` 节点或受控 DOM 创建。

## 7. 修改 class 比到处写行内 style 更易维护

```js
row.classList.toggle('is-critical', order.priority === 5);
row.classList.add('is-loading');
row.classList.remove('is-loading');
```

JavaScript 负责状态，CSS 负责表现。少量动态尺寸可用 style/custom property：

```js
progress.style.setProperty('--progress', `${percent}%`);
```

不要用 class 作为隐藏的业务状态真相；页面刷新或其他渲染会丢失，应有明确数据状态。

## 8. Attribute 和 property 的职责不同

```js
checkbox.setAttribute('checked', ''); // 初始/HTML 属性语义
checkbox.checked = true;              // 当前控件状态
```

布尔属性按“存在即真”解释：

```html
<button disabled="false">仍然是禁用</button>
```

要启用应移除 `disabled` 或设置 property 为 false。ARIA 属性的字符串值有自己的规范，不能按普通布尔属性套用。

## 9. 插入和移动节点有明确行为

```js
container.append(child);
container.prepend(child);
target.before(node);
target.replaceWith(node);
node.remove();
```

同一个节点 append 到新父元素时会移动，不会自动复制。需要复制可用 `cloneNode(true)`，但事件监听器和运行时状态不一定随深克隆复制。

大量节点可先放入 `DocumentFragment` 或一次性构建，再插入，减少反复 DOM 操作。

## 10. 浏览器用事件通知“发生了什么”

```js
button.addEventListener('click', event => {
  console.log(event.type, event.currentTarget);
});
```

事件可能来自用户（click、input、keydown）、网络/资源（load、error）、页面生命周期或代码主动派发。

事件监听器是异步入口：注册时不会立即执行，事件发生后由事件循环安排回调。

## 11. 事件传播有捕获、目标和冒泡阶段

```text
window → document → body → list → button   捕获
                                  button    目标
button → list → body → document → window   冒泡
```

默认监听通常在冒泡阶段。`event.target` 是最初触发节点，`event.currentTarget` 是当前正在执行监听器的节点。

点击按钮内部图标时，target 可能是 `svg`，currentTarget 仍是注册监听的 button。

## 12. stopPropagation 不应成为默认修复

`stopPropagation()` 阻止事件继续传播，可能破坏上层事件委托、分析或组件协调。真正需要隔离嵌套交互时再用，并说明为什么。

`stopImmediatePropagation()` 还阻止同一节点后续监听器，更强也更难推理。

很多“父级也触发”问题可通过检查 target/closest 或调整交互结构解决，不必全局阻断。

## 13. preventDefault 阻止浏览器默认动作

```js
form.addEventListener('submit', event => {
  event.preventDefault();
  // 用 JavaScript 提交
});
```

它不会阻止事件传播；`stopPropagation` 也不会阻止默认动作。

只有准备提供等价行为时才阻止默认动作。例如拦截链接却不导航，会破坏键盘、复制链接和新窗口能力。

监听器若是 passive，则不能阻止默认滚动；滚动性能相关场景要理解配置。

## 14. 事件委托用一个祖先处理动态子项

```js
list.addEventListener('click', event => {
  const button = event.target.closest('[data-action="close"]');
  if (!button || !list.contains(button)) return;

  closeOrder(button.dataset.orderId);
});
```

利用冒泡，一个监听器可处理当前和以后新增的按钮，避免为每行单独绑定。`closest` 需配合容器边界检查，防止匹配到不属于当前组件的祖先。

并非所有事件都以相同方式冒泡，需要时查规范。

## 15. 监听器要有可清理的函数引用

```js
function handleClick(event) { ... }

button.addEventListener('click', handleClick);
button.removeEventListener('click', handleClick);
```

若 remove 时新写一个箭头函数，它不是原来的函数对象，无法移除。

也可以使用 `AbortController` 管理一组监听器：

```js
const controller = new AbortController();
button.addEventListener('click', handleClick, { signal: controller.signal });
controller.abort();
```

组件销毁时清理计时器、监听器和观察器，避免内存与重复行为。

## 16. click 不等于所有键盘交互

原生 button 在 Enter/Space、鼠标和触摸下产生正确行为，因此通常只监听 click 即可。给 div 加 click 后还必须自己实现焦点和键盘语义，这是不必要的负担。

快捷键监听应：

- 检查用户是否正在输入；
- 不覆盖浏览器/辅助技术常用键；
- 根据 `event.key` 表达含义，而非只靠键码；
- 允许关闭或重新绑定复杂快捷键。

## 17. input 和 change 触发时机不同

- `input`：值随用户编辑变化时频繁触发；
- `change`：控件值完成确认或失焦等时机触发，随类型不同；
- `blur`：失去焦点，不冒泡（`focusout` 会冒泡）；
- `submit`：表单提交行为发生。

即时搜索可监听 input 并防抖；昂贵校验不应每个按键都阻塞主线程。最终提交仍做完整验证。

## 18. 监听 form 的 submit，而不是只监听按钮 click

用户可点击按钮，也可在输入框按 Enter，辅助技术也会触发表单提交。正确入口：

```js
form.addEventListener('submit', async event => {
  event.preventDefault();
  // 提交逻辑
});
```

只监听按钮 click 会漏掉合法提交路径。若有多个提交按钮，可从 `event.submitter` 判断是“保存草稿”还是“正式提交”。

## 19. FormData 按浏览器表单规则收集字段

```js
const data = new FormData(form);
const title = data.get('title');
const tags = data.getAll('tags');
```

成功控件才会提交：需要有 name、未被 disabled，并符合控件提交规则。checkbox 未选中通常完全没有该字段；同名多值需要 `getAll`。

FormData 值可能是 string 或 File，不能无条件当字符串。

## 20. 约束校验 API 可复用原生规则

```js
if (!form.checkValidity()) {
  form.reportValidity();
  return;
}
```

自定义跨字段错误可用 `setCustomValidity`，修复后要清空：

```js
end.setCustomValidity(end.value < start.value ? '结束时间不能早于开始时间' : '');
```

过度自定义弹窗会丢失浏览器本地化和无障碍行为。原生规则不够时，再构建稳定的内联错误合同。

## 21. 表单状态要区分原始、编辑中和提交结果

常见状态：

```text
pristine：用户未改
dirty：至少改过
touched：访问并离开过字段
submitting：正在提交
success：提交成功
serverErrors：服务端字段/全局错误
```

不要页面一加载就把所有必填项标红。错误显示时机应帮助修复，不应在用户尚未操作时制造噪声。

提交中可禁用重复提交，但要保留加载说明，并考虑请求失败后恢复。

## 22. 服务端字段错误要映射回可见控件

API 可能返回：

```json
{
  "code": "VALIDATION_FAILED",
  "fieldErrors": {
    "title": "标题至少需要 3 个字符"
  }
}
```

前端应：

- 把错误关联到对应字段；
- 设置 `aria-invalid` / `aria-describedby`；
- 在顶部提供摘要；
- 把焦点移到可理解的位置；
- 保留用户输入；
- 清除已修复字段的旧错误。

字段名映射是前后端合同，不应靠错误文案字符串猜。

## 23. 自定义事件可以表达组件事实

```js
element.dispatchEvent(new CustomEvent('workorder:closed', {
  bubbles: true,
  detail: { workOrderId: 'WO-42' },
}));
```

它适合 Web Component 或小型 DOM 模块间协作。detail 仍是同一页面中的对象引用，不是安全隔离，也不是跨进程领域事件。

事件名、冒泡和 detail 合同要明确，避免把所有内部状态广播到 document。

## 24. MutationObserver 观察 DOM 变化

```js
const observer = new MutationObserver(records => { ... });
observer.observe(container, { childList: true, subtree: true });
```

用于集成无法直接控制的 DOM、监测动态区域等。若自己控制数据和渲染，直接在更新点执行行为通常更清楚。

观察范围过大会产生大量记录；不再需要时 `disconnect()`。ResizeObserver、IntersectionObserver 分别适合尺寸和可见交叉观察。

## 25. DOM 更新要避免读写交错造成强制布局

浏览器可能延迟布局。若循环中反复写样式、立刻读 `getBoundingClientRect`，会被迫同步计算：

```text
写 → 读布局 → 写 → 读布局 → ...
```

更好：先批量读取所需尺寸，再批量写入；视觉更新可用 `requestAnimationFrame` 与下一帧协调。

不要只凭规则猜性能，用 Performance 工具确认是否真的出现频繁 Layout。

## 26. DOM 中的不可信内容必须留在文本边界

安全默认：

```js
element.textContent = untrustedText;
input.value = untrustedText;
url.searchParams.set('q', untrustedText);
```

危险边界包括：

- `innerHTML` / `outerHTML`；
- `insertAdjacentHTML`；
- 动态脚本 URL；
- `eval` / `new Function`；
- 拼接事件属性；
- 未限制的 `javascript:` URL。

需要富文本时使用适合 HTML 的成熟 sanitizer，并配置允许标签/属性；输入校验不能替代输出上下文处理。

## 27. 焦点是 DOM 状态的一部分

```js
dialog.showModal();
firstField.focus();
```

动态插入错误、打开弹窗或切换页面后，视觉变化不一定被键盘/屏幕阅读器感知。要管理：

- 打开前记住触发元素；
- 弹窗内合理初始焦点；
- Tab 不进入背后页面；
- 关闭后恢复焦点；
- 删除节点前避免焦点丢到 body。

原生 `dialog` 提供部分能力，但仍需测试浏览器与设计合同。

## 28. 这篇的整体地图

```text
HTML → 浏览器解析为 DOM 树
  → 查询和创建 Element
  → 用 text/property/class 安全更新
  → 事件经过捕获、目标、冒泡
  → 表单 submit 统一收集和验证
  → 异步结果映射回状态、错误和焦点
  → 销毁时清理监听器与观察器
```

必须掌握：DOM 是当前对象树，不是源码文件；`textContent` 与 `innerHTML` 安全边界不同；target 与 currentTarget 不同；preventDefault 不会停止传播；表单监听 submit；监听器和观察器要清理。

Selection、Range、Shadow DOM 和完整 ARIA 组件模式属于“需要时查询”。
