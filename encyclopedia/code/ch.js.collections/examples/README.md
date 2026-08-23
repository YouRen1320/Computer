# ch.js.collections 可运行示例

这个示例将工单快照转换成三个独立结果：`updated` 应用 `Map` 补丁但不修改输入；`byStatus` 保留全部快照与首次分组顺序；`unique` 用 `Set` 保留首次出现的 ID。运行 `./verify.sh`，verifier 会做语法检查、严格断言、stdout 精确比较并要求 stderr 为空，只依赖 Node 内建模块。
