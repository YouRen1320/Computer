# ch.js.object-model 私有参考解

仅在独立修复后核对。参考解保持点调用接收者，只向实例写 `kind`，并在工厂中为每个实例创建 `notes`。无状态方法仍由原型共享，formatter 用组合传入，`class` 私有状态通过公开 getter 验证。运行 `./verify.sh` 应零退出。
