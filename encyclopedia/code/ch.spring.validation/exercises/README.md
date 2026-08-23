# 练习：让校验发生在用例调用之前
+
## 同一验证入口的状态合同

只修改 README 指定的 `src/main` 可编辑 starter，测试、POM 与验证器保持不变，然后每次都运行 `./verify.sh`。

- `0` + `EXERCISE_GREEN`：登记的测试数量全部通过，状态为 `completed`；
- `41` + `EXPECTED_RED`：测试数量、唯一失败数和本章 sentinel 精确匹配公开 starter；
- `43`：编译、依赖、测试数量、失败形状或工具环境不在上述两种已知状态，必须先读日志诊断。

离线绿灯只覆盖本练习登记的合同；涉及 PostgreSQL/Testcontainers 的章节仍需正文或 lab 明示的真实环境证据。

starter 的 DTO 已声明 `@NotBlank`，但 Controller 入参故意没有触发级联校验。先运行 `./verify.sh`，确认只有 `EXPECTED_VALIDATION_BEFORE_USE_CASE` 红灯；再修复 MVC 边界，使空白描述返回 400 且用例调用次数保持为零。

验证器既接受未经修改的确定性红灯，也接受完成后的全绿；不要把约束搬进用例或修改测试期望。
