# 私有解答：公共契约测试

`src/WorkOrderSearch.test.ts` 展示最小正确提交：先看加载状态，再等待外部 Promise，最后通过可见按钮触发并断言事件载荷。运行 `bash verify.sh` 只做提交结构检查；章节示例与实验承担真实 Vitest 执行。
