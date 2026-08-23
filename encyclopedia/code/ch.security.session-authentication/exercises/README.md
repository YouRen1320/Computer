# Session 认证生命周期练习

补全 `src/SessionAuthenticationChallenge.java` 的 6 个 `TODO`：强密码记录、统一失败、ID 轮换、恢复一次性消费、credential version/撤销校验和并发上限。

```bash
./verify.sh
```

starter 应先以 `NOOP_PASSWORD_ACCEPTED` 红灯失败。完成后目标输出：

```text
challenge_valid=true password=true uniform=true rotation=true reset=true revocation=true concurrency=true
EXERCISE PASS jdk=25 mode=offline
```

练习没有真实密码学；`PasswordRecord` 只描述由成熟 `PasswordEncoder` 产生的记录元数据。
