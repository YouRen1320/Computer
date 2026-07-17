# 最小页面与合成 DevTools 证据

`public/` 是一个不依赖框架的 FactoryCare 工单观察页；`evidence/` 保存固定的合成 HAR、DOM 摘要和渲染时间线。合成工件用于训练“请求→DOM/CSSOM→layout/paint/composite”的关联，不冒充真实浏览器录制。

运行离线预言：

```bash
./verify.sh
```

若要人工补齐 canonical DevTools 证据，可在本目录运行 `python3 -m http.server 4173 --directory public`，再用真实浏览器重新录 HAR、DOM、截图与 Performance trace；必须记录浏览器完整版本、视口、缓存/reload 条件并先脱敏。离线 verifier 不执行这一步。
