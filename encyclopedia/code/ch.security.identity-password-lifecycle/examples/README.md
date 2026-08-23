# 密码存储边界示例

这个纯 JDK 25、完全离线的示例展示：

- PBKDF2-HMAC-SHA-256 600,000 次与 128-bit 独立 salt；
- 在派生结果上用数据库外 pepper 做 HMAC-SHA-256；
- 存储算法、参数、salt、verifier、`pepper_id`，不存密码或 pepper 值；
- 同一训练口令的两个记录具有不同 salt/verifier；
- 使用 `MessageDigest.isEqual` 比较，并尽量清理临时数组。

```bash
./verify.sh
```

验证运行使用 `TestOnlySaltSource` 生成确定但不同的 salt；生产路径必须使用 `SecureRandomSaltSource` 或身份平台认可的 CSPRNG。所有口令和 pepper 都是仓库内显式 synthetic 值，输出会额外检查它们没有泄露。

## 适用边界

PBKDF2 参数取自 2026-07-17 复核的 OWASP FIPS-oriented 下限，只为用 JDK 标准 API 展示机制；它不是所有系统的首选算法，也不表示 FactoryCare 需要 FIPS。OWASP 当前优先建议 Argon2id。FactoryCare 生产密码、MFA 和 Token 由外部 IdP 管理，不应复制此示例自建登录。
