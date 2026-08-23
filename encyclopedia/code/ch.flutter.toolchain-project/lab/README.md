# 实验：选择正确的 Flutter 刷新层级

阅读 `cases.yml`，先填写每种变化应使用的最小刷新层级，再运行验证。这里用纯数据模型训练判断；真实验收仍要在 Flutter 进程中记录日志。

```bash
./verify.sh
```

实验包含一个注入故障：把 `initState` 变化误判为 hot reload。验证器应能定位该行；修复后重跑为绿。
