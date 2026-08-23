# 公开练习：异常传播与资源释放

编辑 `starter.dart` 中的 `importSafely`：

- 成功读取时返回原值；
- 未知的 `StateError` 必须保留原类型和堆栈向上传播；
- 无论成功或失败，资源都必须且只能关闭一次。

不要用宽泛 `catch` 把失败伪装成空字符串。运行 `./verify.sh`：初始 starter 为
expected-red（退出 `41`），合同全部满足后退出 `0`，非预期工具或编译故障退出 `43`。
