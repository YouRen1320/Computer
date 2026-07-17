# 组件测试与 E2E 边界观察例

组件测试通过公开 DOM、用户动作与 emitted payload 覆盖正常、空、错误、重试和竞态；repository 是唯一 mock 边界。`e2e/login-work-order.spec.ts` 描述登录到打开工单的真实浏览器路径，使用 role/label locator 和 API route stub。

```bash
./verify.sh
```

该命令运行 8 个 happy-dom 组件测试、Vite 构建和 E2E 规范静态检查，**不会启动 Playwright 浏览器**。只有另行安装匹配浏览器并成功运行 `pnpm test:e2e` 才能补齐 canonical 的真实浏览器证据。
