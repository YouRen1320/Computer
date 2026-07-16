# 审计事实与隐私边界练习

修复 `src/AuditPrivacyChallenge.java` 中七个 `TODO`：允许字段、必要身份、提交事实、只追加、租户可见性、追踪与责任主体分离，以及掩码展示。

```bash
./verify.sh
```

起始代码必须稳定失败，首个失败标记为 `SECRET_FIELD_ACCEPTED`。不要删除负向断言或把追踪 ID 当作 actor。练习只处理合成枚举和标识符，不应加入真实账户、联系信息或凭据。
