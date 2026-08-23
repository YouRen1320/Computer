# 幂等与乐观并发故障注入实验

验证器先比较安全基线，再逐项注入：

- `SIDE_EFFECT_BEFORE_CLAIM`：先做业务再声明 key；
- `KEY_ONLY_SCOPE`：key 未绑定 tenant/actor/operation；
- `PAYLOAD_NOT_BOUND`：同 key 不比较 fingerprint；
- `RESPONSE_NOT_SAVED`：重放时临时重建响应；
- `VERSION_NOT_IN_WHERE`：写入不比较 expected version；
- `UPDATE_ZERO_IGNORED`：影响 0 行仍返回成功；
- `BLIND_RETRY`：刷新 version 后强套旧意图。

```bash
./verify.sh
```

两个 version 写使用 `CountDownLatch` 同时释放，断言成功集合大小，不假定线程赢家。实验只模拟数据库裁决；真实 T4 仍需两个 PostgreSQL 连接、唯一约束、事务回滚与 Testcontainers 证据。
