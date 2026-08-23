# 模块化单体边界离线示例

确定性依赖图展示 users/devices/workorders 的公开 API、internal 隔离、允许边、模块事件和基于证据的“保持单体”结论。

```bash
./verify.sh
```

它不启动 Spring Modulith，不能替代 `ApplicationModules.verify()`、`@ApplicationModuleTest` 或真实事务测试。
