# 探针与指标边界示例

示例用一个显式 probe policy 区分进程存活与数据库就绪，并用 Micrometer 1.17 的 SimpleMeterRegistry 证明工单 counter 只使用固定 `priority/result` 标签。它不启动 HTTP endpoint，也不声称验证真实 PostgreSQL。

运行 `./verify.sh`，固定结果为 8 个测试通过。
