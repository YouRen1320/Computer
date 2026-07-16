# 练习：不要把冲突包装成 HTTP 200

starter 的 ProblemDetail body 已声明 409，却故意用 `ResponseEntity.ok` 写出。先运行 `./verify.sh`，确认只有 `EXPECTED_NON_2XX_PROBLEM` 红灯；再让 HTTP status 与 body.status 一致，同时保留安全稳定的错误 body。

验证器接受未经修改的确定性红灯或完成后的全绿；不要删除协议断言或把 body.status 改为 200。
