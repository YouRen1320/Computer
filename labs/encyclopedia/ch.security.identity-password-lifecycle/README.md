# 凭据生命周期与恢复实验

这是一个纯 JDK 25、内存内、固定时钟的身份生命周期实验。所有账号使用 `.invalid` 域名，所有口令、Token、MFA 因素和 pepper 都以 `SYNTHETIC` 标记；没有网络、邮件、环境变量或外部账号。

```bash
./verify.sh
```

基线覆盖：待验证注册、验证 Token 一次性、PBKDF2 + 独立 salt + 数据库外 pepper、统一登录/重置公开结果、三次失败后的临时 throttle、过期与一次性 reset Token、改密后旧密码/旧 session 撤销、MFA 更换重新认证、管理员恢复审计与审计秘密扫描。

脚本还运行四个显式故障模式：

- `UNSAFE_STORAGE` 只把 schema 标记为可逆存储，不实现或保存明文；
- `FIXED_SALT` 使用命名清楚的测试故障源；
- `REPLAY_RESET` 重新打开已消费的 synthetic Token；
- `OLD_SESSION_SURVIVES` 跳过凭据版本递增和 session 撤销。

每个故障必须非零退出并给出稳定 marker。故障分支只为验证预言，不是可采用实现。

## 生产边界

确定性 salt/Token source 只用于测试；同文件同时给出 `SecureRandom...Source` 作为边界提示。PBKDF2 参数用于无依赖教学，并不替代目标环境算法选择与基准。FactoryCare 生产密码、MFA、恢复和 Token 签发由外部 IdP 管理，本实验不得成为生产认证服务。
