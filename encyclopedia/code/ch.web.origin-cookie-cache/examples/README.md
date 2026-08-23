# Origin、Cookie、CORS 与 Cache 固定矩阵

`matrix.json` 用三个合成 HTTPS Origin 表达 same-origin、cross-origin/same-site 和 cross-site 场景。oracle 独立计算 Origin tuple、Cookie 候选、Fetch credentials、CORS 可读性、preflight 与 ETag/304 复用，不依赖图形浏览器。

```bash
./verify.sh
```

此绿灯只证明规范化教学矩阵内部一致。它不验证真实 DNS/TLS、第三方 Cookie/存储分区、浏览器 UI、代理/CDN 或 FactoryCare session；真实实验须固定浏览器完整版本并保存 Network/Console/服务端证据。
