# 修复连接未归还
+
## 同一验证入口的状态合同

只修改 README 指定的 `src/main` 可编辑 starter，测试、POM 与验证器保持不变，然后每次都运行 `./verify.sh`。

- `0` + `EXERCISE_GREEN`：登记的测试数量全部通过，状态为 `completed`；
- `41` + `EXPECTED_RED`：测试数量、唯一失败数和本章 sentinel 精确匹配公开 starter；
- `43`：编译、依赖、测试数量、失败形状或工具环境不在上述两种已知状态，必须先读日志诊断。

离线绿灯只覆盖本练习登记的合同；涉及 PostgreSQL/Testcontainers 的章节仍需正文或 lab 明示的真实环境证据。

starter 在成功查询后仍把连接留在 active 状态。只能修改 `ConnectionBorrower`，用明确资源所有权修复；不要放宽测试、增大池或吞掉异常。

运行 `./verify.sh` 应稳定得到一个 `EXPECTED_CONNECTION_RETURNED` 红灯。完成后同一入口会识别全绿；私有答案只用于课程验证。
