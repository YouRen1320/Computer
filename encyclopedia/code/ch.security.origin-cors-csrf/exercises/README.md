# Origin、CORS 与 CSRF 边界练习

补全 `src/OriginCorsCsrfChallenge.java` 的 6 个 `TODO`。完成后的离线断言必须证明：

- CORS 允许来源使用完整 origin 精确匹配，不能使用后缀或子串；
- same-origin 比较 scheme、host、port 三元组；
- 凭据型响应不能组合 `Access-Control-Allow-Origin: *`；
- 预检请求不需要 Session Cookie；
- 携带浏览器 Session 的不安全方法同时要求可信来源和正确 CSRF Token；
- signed double-submit 需要 Cookie/Header 相等、有效签名并绑定当前 Session；
- `GET` 不得作为状态变更入口。

```bash
./verify.sh
```

起始代码应以 `ORIGIN_SUFFIX_BYPASS` 失败，且脚本确认恰有 6 个 `TODO`。修完后目标输出为：

```text
challenge_valid=true origin=true cors=true csrf=true double_submit=true safe_method=true
EXERCISE PASS jdk=25 mode=offline
```

练习只处理合成元数据，不发网络请求、不解析真实 Cookie，也不要求实现密码学。`signatureValid` 表示服务端密码学验证的结果，而不是可由客户端自报的字段。
