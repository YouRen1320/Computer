# 实验：混合版本部署证据门禁

运行 `./verify.sh`。绿色只证明合成发布记录符合已声明门禁；故障测试覆盖新旧版本 schema 不兼容、过早 contract、迁移失败仍切流量、坏 canary 仍晋级、contract 后错误回滚旧应用、重建制品和缺少前向修复。

真实 T4 演练必须在隔离 PostgreSQL 上执行实际迁移，记录 Flyway schema history、锁等待、batch checkpoint、两版应用契约、流量比例、门禁窗口、制品 digest 和恢复结果。
