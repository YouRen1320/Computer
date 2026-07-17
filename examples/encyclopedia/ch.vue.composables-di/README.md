# Composable 合同观察例

本例把工单查询写成 `useWorkOrderQuery`。每次调用拥有独立的状态与请求；无效化或卸载会中止请求；组件只依赖 `WorkOrderRepository` 端口和 typed `Symbol` key。替换 fake/HTTP repository 时，面板的输入、输出与 DOM 合同不变。

```bash
./verify.sh
```

成功输出包含 `instances=isolated cleanup=zero repository=substitutable`。验证使用 happy-dom 与内存 fake，没有发起真实 HTTP、启动真实浏览器或覆盖 SSR。
