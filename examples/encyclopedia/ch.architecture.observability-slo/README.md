# 完整相关链示例

本示例用一份合成 `telemetry.json` 表达 FactoryCare 创建工单从 API、领域事务、outbox、consumer 到 Python 的证据。它同时验证：

- 六条结构化日志都带真实 trace/span 引用；
- 六个 span 构成一个可达的因果树；
- metric label 只使用允许的低基数维度；
- liveness 不依赖外部系统，readiness 只纳入核心 PostgreSQL，可选 Python 可降级；
- 10,000 eligible、8 bad、99.9% SLO 可重算为 99.92%，错误预算余 2；
- 瞬时 burn 不 page，长短窗口都持续超阈值才 page；
- 合成遥测不含秘密字段。

运行：

```bash
./verify.sh
```

`verify.sh` 只调用 Ruby 标准库并把预言输出与 `expected.out` 比较。它不连接遥测后端，也不证明生产采集、采样、保留、权限或告警投递。
