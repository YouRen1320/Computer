# ch.js.dom-mutation 可运行示例

示例从固定语义外壳渲染三条工单，验证顺序、纯文本注入边界、checkbox 当前 property、目标状态最小更新和删除。自动运行环境是 happy-dom 17.6.3 模拟，不等同真实浏览器、布局、可访问树或 CSP。

运行 `./verify.sh`。最终 stdout 精确匹配 expected.stdout；真实 evergreen 浏览器检查仍需另行记录。
