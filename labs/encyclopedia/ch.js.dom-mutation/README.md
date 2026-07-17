# ch.js.dom-mutation 实验

基线执行固定序列：初始空壳 → 渲染 3 条 → 更新 WO-2 → 删除 WO-1，并断言数量、顺序、文本、property 与语义父子关系。

`faults/` 隔离注入 `DOM_SELECTION_DRIFT_MISSING_ROOT`、`ATTRIBUTE_PROPERTY_BOOLEAN_DRIFT`、`UNSAFE_INNER_HTML_CREATED_NODE`、`SEMANTIC_DOM_BREAKAGE_UL_CHILD`。自动运行使用 happy-dom 模拟；真实浏览器 DevTools 检查仍需独立执行。
