# 公开红灯：参数复用后刷新详情

直接执行 `./verify.sh` 应输出 `EXPECTED_RED`。当前页面只快照第一次 `route.params.workOrderId`；从 `/work-orders/WO-1` 导航到 `/work-orders/WO-2` 时 Router 复用组件实例，setup 不会重跑，内容仍是 WO-1。

任务：监听特定 param，把每个新值映射给 `loadWorkOrder`，并用 immediate 覆盖直接深链接。不要监听整个 route、销毁复用优化或削弱检查器。

