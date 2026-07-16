# FilterChain、Context 与异常翻译练习

补全 `src/SecurityArchitectureChallenge.java` 的 6 个 `TODO`：精确公共入口、第一匹配链、默认拒绝授权、401/403 翻译、Filter 依赖顺序和请求结束清理。

```bash
./verify.sh
```

starter 必须先以 `PUBLIC_MATCHER_TOO_WIDE` 红灯失败。完成后目标输出：

```text
challenge_valid=true first_match=true default_deny=true exceptions=true order=true cleanup=true
EXERCISE PASS jdk=25 mode=offline
```

练习只模拟架构不变量；不得把答案类当成生产 Spring Security 配置。
