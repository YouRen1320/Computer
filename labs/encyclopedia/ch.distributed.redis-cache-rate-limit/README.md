# Redis 缓存与限流故障注入实验

验证器先检查安全基线，再逐项注入：漏租户键、更新不失效、同刻 TTL、非原子 `INCR/EXPIRE`、分离 check/add、昂贵端点错误 fail-open、命中跳过当前授权。

```bash
./verify.sh
```

每个 fault 必须出现唯一 oracle；修复后应重跑同一断言。实验是离线语义模型，不替代 Redis 8.x 的多连接、Lua、网络超时和 Docker 故障证据。
