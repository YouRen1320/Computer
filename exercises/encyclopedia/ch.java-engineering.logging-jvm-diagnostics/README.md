# 独立练习：日志安全与证据门禁

starter 提供一个纯 JDK 25 小程序，四个策略故意未完成：

1. 按规范化后的键识别 authorization/password/token/cookie/secret/api_key，并输出 `[REDACTED]`；
2. correlation ID 只允许 3—64 个受控字符，换行必须无效；
3. 单张线程快照不能被标为“持续阻塞”，两张及以上才通过教学门禁；
4. 性能结论至少有 5 个测量样本和 1 次 warmup；这只是练习下限，不是生产统计保证。

先预测 starter 的第一条失败标记，再运行：

```bash
./verify.sh
```

验证器预期当前程序非零退出并输出 `EXERCISE READY`。完成所有 TODO 后，直接编译运行程序，应得到两行稳定通过输出。

## 限制

不得读取真实环境变量、token、PID 或当前时间；不得通过删除断言、把 `[REDACTED]` 写死到输出、或把所有字段都删除来“通过”。完成后说明：为什么两张 dump 和五个样本仍不足以自动判根因。
