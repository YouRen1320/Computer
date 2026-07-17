# 服务端状态与受控竞态示例

本示例用无网络依赖的 Node 状态控制器模拟 Vue Composable 的核心合同：互斥状态、request identity、AbortController、retry、cancel 与 dispose。受控 Promise 精确安排完成顺序。

```sh
./verify.sh
```

预期退出码为 `0`。这里没有运行 Vue、Vitest、浏览器 Fetch、真实服务器或 DOM；绿灯只证明离线状态合同。
