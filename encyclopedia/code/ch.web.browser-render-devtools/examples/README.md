# 最小页面与合成 DevTools 证据

`public/` 是一个不依赖框架的 FactoryCare 工单观察页；`evidence/` 保存固定的合成 HAR、DOM 摘要和渲染时间线。合成工件用于训练“请求→DOM/CSSOM→layout/paint/composite”的关联，不冒充真实浏览器录制。

运行离线预言：

```bash
./verify.sh
```

若要人工补齐 canonical DevTools 证据，可在本目录运行 `bash ./serve.sh 4173`。脚本只绑定 `127.0.0.1`，会从本机已有的 Python、Ruby、JDK `jwebserver` 中选择一个后端；浏览器访问 `http://127.0.0.1:4173/index.html`，完成后在服务终端按 `Ctrl-C` 停止。重新录制 HAR、DOM、截图与 Performance trace 时，必须记录浏览器完整版本、视口、缓存/reload 条件并先脱敏；离线 verifier 不执行真实浏览器步骤。
