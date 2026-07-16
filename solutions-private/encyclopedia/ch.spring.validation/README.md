# 私有答案：在 MVC 入站边界触发校验

答案在 `@RequestBody` 参数上添加 `@Valid`。合法请求仍返回 201；空白描述在 Controller 方法调用前变成 400，`RecordingUseCase` 保持零次调用。运行 `./verify.sh` 应有两个测试通过。
