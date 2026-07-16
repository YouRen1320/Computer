# 练习：让校验发生在用例调用之前

starter 的 DTO 已声明 `@NotBlank`，但 Controller 入参故意没有触发级联校验。先运行 `./verify.sh`，确认只有 `EXPECTED_VALIDATION_BEFORE_USE_CASE` 红灯；再修复 MVC 边界，使空白描述返回 400 且用例调用次数保持为零。

验证器既接受未经修改的确定性红灯，也接受完成后的全绿；不要把约束搬进用例或修改测试期望。
