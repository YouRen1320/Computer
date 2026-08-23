# 独立练习：恢复 FIFO、LIFO、安全删除与稳定快照

关闭 AI，限时 35 分钟。starter 能零警告编译，但第一个 oracle 必须失败；验证器把这标为 `STARTER EXPECTED FAILURE`，不是练习通过。

要求：

1. `dispatch` 按 FIFO 返回三条工单，且不修改输入；
2. `undo` 按 LIFO 返回三次动作；
3. `publishedSnapshot` 返回不可修改的稳定浅快照，源列表后续追加不能改变它；
4. 删除两个相邻 cancelled 工单，不能因索引移动漏删；
5. 不 catch 并忽略 `ConcurrentModificationException`，不使用旧 `Stack`；
6. 保持空输入可处理，并让独立空队列 `remove` 故障继续失败；
7. 最终输出 `exercise.assertions=12 passed` 和 `EXERCISE PASS`。

```bash
cd exercises/encyclopedia/ch.java-engineering.sequential-collections
./verify.sh
```

先按 TODO 顺序修复，每次只改一个合同并重跑。不要打开私有解。完成后做变更题：调度时跳过 cancelled，但原始 List 与发布快照都必须保留全部输入；新增空、全取消、首尾取消断言。
