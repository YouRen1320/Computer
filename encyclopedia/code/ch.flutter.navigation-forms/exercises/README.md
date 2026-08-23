# 公开练习：类型化页面返回值

编辑 `starter.dart` 的页面结果生产函数，让导航生产者和消费者共享 `EditResult` 合同：

- 保存成功返回 `Saved(orderId)`；
- 用户取消返回 `Cancelled`；
- `decodeResult` 对合同外值继续 fail closed，抛出 `FormatException`。

不要让 `bool`、`Map` 或 magic string 穿过路由边界。初始 `./verify.sh` 返回 `41`，修复后
返回 `0`，非预期编译或工具失败返回 `43`。
