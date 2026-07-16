# Session 登录故障实验

实验用密码记录元数据、固定时钟和合成 Session 重放七个生命周期故障：

- `NOOP_PASSWORD`：接受原文比较记录；
- `RESET_REPLAY`：恢复授权可重复消费；
- `OLD_SESSION_AFTER_PASSWORD_CHANGE`：改密后旧 Session 仍有效；
- `FIXATION_REUSE`：登录继续使用匿名 ID；
- `ACCOUNT_ENUMERATION`：不存在账号与错密码公开失败不同；
- `LOGOUT_CLIENT_ONLY`：登出不撤销服务端记录；
- `CONCURRENT_LIMIT_BROKEN`：超过并发上限仍全部有效。

```bash
./verify.sh
```

每个 fault 必须非零退出并命中稳定 marker。这里不实现真实哈希、网络、数据库或 Spring Session；所有 secret-like 值都是不输出的 synthetic marker。
