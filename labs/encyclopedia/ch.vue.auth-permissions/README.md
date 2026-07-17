# 实验：开放重定向、敏感闪现与客户端授权

实验把三种故障记录为“注入—首个可信证据—修复”，并以受控 bootstrap、恶意 return URL 和直接 API 调用验证修复。

```sh
./verify.sh
```

预期退出码为 `0`。这里的 policy server 只是假 fixture；生产 Cookie/Token、浏览器和 RBAC/ABAC 均未验证。
