# 源码、语句与变量：最小绿色示例

`src/state-trace.mjs` 只使用声明、赋值和输出，展示工单状态快照从 `CREATED` 到 `ASSIGNED` 的线性变化。先阅读 `expected.stdout` 并手工填写状态表，再运行：

```sh
./verify.sh
```

该脚本只负责教学观察，不授权真实 FactoryCare 状态迁移。
