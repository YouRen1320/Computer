# 公开练习：修复焦点、名称与 ARIA 状态

starter 故意使用正 tabindex 和 div role=button，制造 Tab 拦截，遗漏表单 label/图标按钮名称，让 `aria-expanded` 与可见面板冲突，用不安全 DOM 映射错误，并在删除当前节点后丢失焦点。

```bash
./verify.sh
```

公开 starter 必须稳定退出 1。请修改 `answer.html`、`answer.js` 和 `answer.json`，不要修改 oracle/expected-red，也不要查看私有解。目标是静态合同绿灯；随后仍要在真实浏览器/读屏器按同一任务验证。
