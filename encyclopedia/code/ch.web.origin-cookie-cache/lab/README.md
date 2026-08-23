# Origin、SameSite 与缓存头故障实验

`faults.json` 注入四种可重复故障：allow Origin 带 path、cross-site Lax Cookie 被错误期望发送、不变 URL 配长 freshness 导致陈旧 CSS、动态 ACAO 漏 `Vary: Origin`。oracle 证明每个红灯条件确实存在，并要求修复后重放原矩阵。

```bash
./verify.sh
```

建议先填写 [worksheet.md](worksheet.md)。所有域名、Cookie 和缓存内容均为合成值；真实浏览器、HTTPS、第三方 Cookie 与代理 cache 未运行。
