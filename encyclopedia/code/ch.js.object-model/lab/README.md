# ch.js.object-model 实验

`src/object-contract.mjs` 保存属性查找追踪、调用点矩阵和实例身份断言。三个隔离故障分别证明：

- detached 方法触发 `THIS_BINDING_LOSS_DETACHED_METHOD`；
- 修改共享业务原型触发 `PROTOTYPE_POLLUTION_SHARED_BEHAVIOR_DRIFT`；
- 把数组放在原型触发 `SHARED_INSTANCE_STATE_NOT_ISOLATED`。

运行 `./verify.sh`。基线必须精确匹配 stdout；每个故障必须非零退出、stdout 为空且 stderr 含预期标记。故障进程不修改内建原型。
