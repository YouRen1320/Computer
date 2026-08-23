# 可键盘完成的报修表单：离线示例

本目录把原生表单、说明展开、固定 `Problem.fieldErrors` 映射、错误摘要、焦点移动与审计矩阵放在一起。HTML 和 JavaScript 都写明职责、数据源、映射与副作用。

```bash
./verify.sh
```

唯一验证器只做静态合同检查：原生元素、label、无正 tabindex、名称/说明关系、ARIA 状态同步代码、allowlist、`textContent` 和预言矩阵。它不会真的执行 JavaScript、按 Tab、读取 Accessibility tree 或启动读屏器。

要形成真实 G4 证据，请通过本地 HTTP server 打开页面，记录 OS/浏览器/读屏器版本与设置，按 `audit-matrix.json` 执行同一任务，填写实际 focus、role/name/state 与播报。`problem.json` 是虚构错误响应，不调用 FactoryCare 生产 API。
