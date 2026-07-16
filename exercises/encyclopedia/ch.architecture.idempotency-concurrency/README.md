# 幂等与乐观并发独立练习

修复 `src/IdempotencyConcurrencyChallenge.java` 中七个 `TODO`：fingerprint、scope、响应重放、先声明后副作用、版本比较、影响行数和冲突重试。

```bash
./verify.sh
```

起始代码必须稳定失败，首个标记为 `DIFFERENT_PAYLOAD_REPLAYED`。不要删除负向断言，也不要用“总是返回成功”掩盖 0 行更新。
