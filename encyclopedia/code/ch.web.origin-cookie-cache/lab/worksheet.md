# 请求矩阵故障表

| 故障 | 请求是否到服务器 | Cookie 是否候选 | 浏览器是否可读 | Cache 是否联网 | 第一证据 | 修复与重跑 |
|---|---|---|---|---|---|---|
| wrong-origin |  |  |  |  |  |  |
| wrong-samesite-expectation |  |  |  |  |  |  |
| stale-unchanged-url |  |  |  |  |  |  |
| missing-vary-origin |  |  |  |  |  |  |

附问：为什么 curl 200 不能证明浏览器 CORS 可读？为什么强制清缓存不算修复陈旧部署策略？
