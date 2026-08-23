# 公开练习：把假通过改成公共契约测试

只修改 `src/WorkOrderSearch.test.ts`。目标是在不读取 `wrapper.vm` 的前提下，通过可见 DOM 和 `select` 事件验证加载、异步结果与用户动作：

1. 从 `@vue/test-utils` 导入并 `await flushPromises()`；
2. 查询 `[role="status"]` 和 `[aria-label="工单结果"]`；
3. 触发“打开工单”按钮，断言 `wrapper.emitted('select')` 的最小身份载荷；
4. 保留网关 Mock，不要把整个被测组件替换成 stub。

起始文件故意读取实现细节且漏掉异步等待，所以 `bash verify.sh` 预期红灯。此检查不执行真实浏览器。
