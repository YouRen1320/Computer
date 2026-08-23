# 独立练习：维修批次循环

关闭 AI，限时 25 分钟。公开起始代码能编译并终止，但三处标有 `TODO` 的循环状态更新是错的。只修复这三处，不改变固定输入、输出格式或已有 `if` 分支。

规则：按编号 1..5 检查工单；编号 2 暂不可处理，使用 `continue` 跳过；遇到编号 5 立即停止；其余工单计入处理数，并把编号累加到 `totalPriority`。

正确输出：

```text
processed=3
skipped=1
stoppedAt=5
totalPriority=8
```

运行命令：

```bash
cd exercises/encyclopedia/ch.java.loops
rm -rf build && mkdir -p build/classes
javac --release 25 -d build/classes src/MaintenanceBatchChallenge.java
java -cp build/classes MaintenanceBatchChallenge
```

先预测错误版本的四行结果，再修复。变更练习：把停止编号从 5 改为 6，同时把循环上界改为 6，重新手算处理数和总和。故障练习：临时移除 `ticket++`，但不要直接运行无保护的无限循环；先解释哪个状态不再接近退出条件，再恢复。
