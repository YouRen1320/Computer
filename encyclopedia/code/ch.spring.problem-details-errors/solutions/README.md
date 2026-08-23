# 私有答案：让 HTTP 与 ProblemDetail 状态一致

答案用 ProblemDetail 的 status 构造 ResponseEntity，冲突因此同时得到 HTTP 409 与 body.status 409；安全 body 测试保持通过。运行 `./verify.sh` 应有两个测试通过。
