# ch.js.object-model 公开练习（预期红灯）

初始运行 `./verify.sh` 应非零退出，首个稳定标记为 `THIS_BINDING_LOSS_EXERCISE`。按顺序修复：

1. 保留调用接收者，或显式说明为何绑定/显式参数更合适；
2. 让 `customizeKind` 只写目标实例，消除 `PROTOTYPE_POLLUTION_EXERCISE`；
3. 每次创建都初始化新 `notes` 数组，消除 `SHARED_INSTANCE_STATE_EXERCISE`；
4. 保持方法身份共享、私有状态与组合 formatter 断言；
5. 不修改 oracle、expected.stdout 或 verifier。

全部修复后 stdout 必须精确匹配 expected.stdout。private solution 仅在独立完成后核对。
