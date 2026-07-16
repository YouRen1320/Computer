# 不可信输入、XSS 与 SSRF 边界练习

补全 `src/InputBoundaryChallenge.java` 中 6 个 `TODO`：HTML text 编码、安全属性集合、CSRF 来源与 Token、精确出站目标、逐跳重定向和 DNS 绑定一致性。

```bash
./verify.sh
```

起始代码必须以 `ACTIVE_MARKUP_REACHED_SINK` 红灯失败；完成后目标输出：

```text
challenge_valid=true xss=true csrf=true destination=true redirect=true rebinding=true
EXERCISE PASS jdk=25 mode=offline
```

所有 URL 与凭据标记均为合成数据。练习不要求实现 DNS、HTTP client 或富文本 sanitizer；不要把这里的最小 HTML text encoder 复用于属性、JavaScript、CSS 或 URL 上下文。
