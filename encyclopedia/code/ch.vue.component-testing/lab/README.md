# 组件测试与 E2E 边界实验

运行 `bash verify.sh`。它会执行 10 个 happy-dom 组件测试、生产构建和证据边界静态检查。`faults/` 保存实现细节、漏等待、过度 Mock、脆弱选择器四类故障，不会混入健康测试。

`e2e/login-work-order.spec.ts` 是待真实浏览器执行的 Playwright 规格。本资产不下载浏览器，也不把静态检查冒充浏览器执行；因此浏览器结果明确为 `UNVERIFIED`。
