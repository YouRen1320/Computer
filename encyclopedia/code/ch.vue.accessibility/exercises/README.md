# 公开练习：修复动态弹层上下文

只修改 `src/WorkOrderDialog.vue`，让它满足以下公共契约：

1. Teleport 后仍有 `role="dialog"`、`aria-modal="true"`、标题引用和显式标签；
2. 打开时在 `await nextTick()` 后聚焦字段，关闭时把焦点归还给调用控件；
3. Escape 关闭，Tab 与 Shift+Tab 在可用控制之间环绕；
4. 校验错误使用 `role="alert"` 并关联字段，异步完成写入持久的 `role="status" aria-live="polite"` 区域。

起始文件故意存在时机、静默反馈和键盘缺口，`bash verify.sh` 预期红灯。静态检查不会证明真实屏幕阅读器播报或视觉对比度。
