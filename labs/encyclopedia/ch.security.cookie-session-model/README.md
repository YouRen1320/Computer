# Session 固定与失效实验

实验以固定时钟、内存 Session store 和 synthetic ID 重放 FactoryCare 浏览器会话不变量：host-only + Secure + HttpOnly + Lax；登录轮换；旧 ID 拒绝；只接受 Cookie 通道；登出同时服务端撤销和清 Cookie；idle 边界到期。

```bash
./verify.sh
```

脚本还注入四个命名故障：

- `WIDE_COOKIE_SCOPE`：添加父域 Domain；
- `FIXATION_REUSE`：登录后把旧匿名记录直接升级；
- `LOGOUT_CLIENT_ONLY`：只清客户端 Cookie，不撤服务端状态；
- `EXPIRED_ACCEPTED`：到期后继续接受。

每个故障都必须非零退出并报告第一处稳定 marker。故障分支只用于证明预言能抓住问题，不是生产选项。

## 边界

资产不启动 HTTP 服务，不实现真实 Cookie parser、Spring Security、OIDC 或多节点 TTL。ID 只能用于教学且不会输出。真实 Session ID 必须由框架/CSPRNG 生成；实际 Cookie 属性需观察部署后的 `Set-Cookie` 与浏览器行为。
