# ch.js.dom-mutation 公开练习（预期红灯）

运行 `./verify.sh` 应非零退出，首个标记为 `DOM_SELECTION_DRIFT_EXERCISE`。依次修复：

1. 使用 HTML 已声明的固定列表根；
2. 不把 `title` 拼入 `innerHTML`，消除 `UNSAFE_INNER_HTML_EXERCISE`；
3. 让 `ul` 的业务直接子节点都是 `li`，消除 `SEMANTIC_DOM_BREAKAGE_EXERCISE`；
4. 用 checkbox `checked` property 表示当前布尔状态，消除 `ATTRIBUTE_PROPERTY_EXERCISE`；
5. 保留目标状态更新的节点身份与删除顺序；
6. 不改断言、expected.stdout 或 verifier。

自动绿灯仍只是 happy-dom 模拟，不能写成真实浏览器通过。
