# Lab：工单创建表单四方状态矩阵

目标是对初始、输入、非法提交、合法提交和重置保存四方证据：DOM 控件、Vue 模型、原生/客户端错误、`CreateReportRequest`。实验还包含 `faults/DomOnlyReset.vue`，它只重置 DOM，稳定复现 UI 与模型漂移。

```sh
./verify.sh
```

建议先读失败组件并手写第一可信证据，再对照正常组件。自动验证不连接 FactoryCare API，因此不能证明认证、租户隔离、附件完成态、服务端校验或幂等重试。

