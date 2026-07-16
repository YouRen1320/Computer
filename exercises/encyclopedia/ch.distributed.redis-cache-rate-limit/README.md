# Redis 缓存与限流独立练习

修复 `src/RedisCacheRateLimitChallenge.java` 中七个 `TODO`：租户键、提交后失效、TTL 抖动、计数/到期原子性、精确阈值、滑动窗口清理和昂贵端点故障策略。

```bash
./verify.sh
```

起始代码必须稳定红灯，首个证据为 `MISSING_TENANT_IN_KEY`。不要删除断言或把所有故障都改成 fail-open。
