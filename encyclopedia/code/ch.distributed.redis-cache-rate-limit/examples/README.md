# Redis 缓存与限流离线示例

本示例用内存中的确定性 Redis 替身演示租户化 cache-aside、命中/未命中一致、更新后失效、原子固定/滑动窗口和 endpoint 级故障策略。

```bash
./verify.sh
```

它不打开网络、不启动 Redis/Docker，也不声称证明真实 TTL 精度、Lua 原子性、连接超时或多实例行为；这些仍需 Redis 8.x/Testcontainers 的 T4 证据。
