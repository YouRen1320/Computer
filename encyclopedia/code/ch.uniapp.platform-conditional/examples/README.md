# 双目标平台适配器示例

本示例用 Node.js 模拟 H5 与微信小程序的“编译清单”和运行时能力夹具。它验证统一端口、支持/无能力/失败降级和每个目标分支命中，不执行真实 uni-app 构建。

```bash
./verify.sh
```

预期输出：`UNIAPP_PLATFORM_CONDITIONAL_EXAMPLE_PASS ...`。

证据边界：`buildTarget()` 只是教学用离线选择器；真实项目必须用 DCloud CLI/HBuilderX 生成两份产物，再在浏览器、微信开发者工具和真机验证。
