# Origin、CORS 与 CSRF 边界练习：私有解答

这是公共练习的教师预言，实现精确 origin、凭据型 CORS、预检、同步 Token 与 signed double-submit 边界。

```bash
./verify.sh
```

脚本使用 JDK 25 离线编译、比对固定输出并拒绝残留 `TODO`。它只验证决策谓词，不启动浏览器或服务器；`signatureValid` 代表服务端验证结果，不是一个可供生产代码直接信任的请求字段。
