# 独立练习：工单分级与状态动作

关闭 AI，限时 25 分钟。`src/TicketRoutingChallenge.java` 能编译，但有三类故意错误的分支规则。相同规则因尚未学习方法而在四个最小片段中重复；修复每一处同类条件，并修复标有 `TODO` 的 switch 结果，不改变固定输入和输出格式。

固定预期：

```text
priority.1=ROUTINE
priority.3=HIGH
priority.5=CRITICAL
priority.0=REJECTED
status.ASSIGNED=WORK
```

要求：

1. 合法优先级是闭区间 1..5；
2. 5 为 `CRITICAL`，3..4 为 `HIGH`，1..2 为 `ROUTINE`；
3. 每个输入只能命中一条规则；
4. `ASSIGNED` 与 `IN_PROGRESS` 都由 switch 表达式返回 `WORK`；
5. 修改前逐个预测错误版本会打印什么，修改后逐行核对。

```bash
cd exercises/encyclopedia/ch.java.branching
rm -rf build && mkdir -p build/classes
javac --release 25 -d build/classes src/TicketRoutingChallenge.java
java -cp build/classes TicketRoutingChallenge
```

变更练习：把合法最大优先级改为 6，并规定 5..6 都是 `CRITICAL`。列出必须一起变化的边界条件与测试输入，避免只改一个数字造成新空洞。完成第一次独立尝试前不要查看私有解析。
