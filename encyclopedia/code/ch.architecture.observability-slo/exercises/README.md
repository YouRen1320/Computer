# 独立练习：补全可观测闭环契约

`answer.json` 是故意错误的 starter。它缺少日志相关字段、把高基数 ID 放进指标、错误配置 health/SLI/告警，也没有完整事故反馈和隐私断言。

第一次运行必须红灯：

```bash
./verify.sh
```

任务是只修改 `answer.json`，直到同一个公开 oracle 通过。不可删除检查、改宽阈值或把错误字符串硬编码为通过。要求：

1. 日志至少有 timestamp/severity/service/event/outcome/trace_id/span_id；
2. HTTP、executor、outbox、consumer、Python 同一因果链，日志 span 存在；
3. metric label 无 trace/workOrder/user/tenant 等高基数 ID，route 使用模板；
4. liveness 无外部依赖，readiness 只纳入 PostgreSQL，可选 Python 降级不摘核心流量；
5. 10,000 eligible、8 bad、99.9% SLO 算出 99.92%、预算 10、余 2；
6. 告警长短窗口 AND，瞬时不 page、持续才 page，且有 owner/runbook；
7. 事故反馈六阶段齐全，秘密字段缺席且使用允许列表。

私有参考答案使用**同一个公开 `verify.rb`**，因此答案绿灯不是另写一个宽松 oracle。
