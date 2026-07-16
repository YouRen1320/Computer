# CORS 与 CSRF 故障重放实验

实验用内存中的合成请求、响应和写计数器验证 FactoryCare 浏览器边界：

- 允许来源的预检在没有 Session Cookie 时成功；
- 未知来源不获得 `Access-Control-Allow-Origin`；
- 携带 Cookie 的状态变更必须同时通过精确来源与 CSRF Token；
- cross-site 表单不能产生写入；
- `GET` 没有副作用；
- CORS 只控制浏览器读取许可，不代替认证、授权或 CSRF 防护。

```bash
./verify.sh
```

脚本在基线通过后重放四个命名故障：

- `WILDCARD_CREDENTIALS`：凭据型 CORS 使用 `*`；
- `CSRF_DISABLED`：跳过来源和 Token 校验；
- `REFERER_ONLY`：用字符串前缀判断 Referer，忽略 Origin 与 Token；
- `GET_MUTATES`：让安全方法产生写入。

每个故障必须非零退出并命中稳定 marker。模型不发网络请求；Session、Token、来源和 Referer 都是合成测试数据。
