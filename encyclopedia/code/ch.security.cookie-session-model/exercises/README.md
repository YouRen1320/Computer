# Cookie 与 Session 不变量练习

补全 `src/CookieSessionChallenge.java` 中 5 个 `TODO`，使纯离线断言同时覆盖：

- Cookie 必须是 host-only、`Path=/`、`Secure`、`HttpOnly`，并显式使用 `Lax` 或 `Strict`；
- 发送判定必须同时检查 HTTPS、精确主机、路径和 same-site 场景；
- 登录前后 Session ID 必须非空且不同；
- 服务端撤销或到期才构成失效，活跃记录不能误判；
- Session ID 只从 Cookie 读取，不接受查询参数回退。

先运行：

```bash
./verify.sh
```

起始代码应以 `UNSAFE_COOKIE_ACCEPTED` 失败；这是练习就绪信号，不是答案。完成后可直接编译运行，目标输出是：

```text
challenge_valid=true cookie=true rotation=true invalidation=true strict_source=true
EXERCISE PASS jdk=25 mode=offline
```

所有主机、ID 和状态均为合成值。练习不启动网络服务，也不模拟完整浏览器 Cookie jar。
