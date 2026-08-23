# 独立练习：恢复多字段方向、稳定性、null 与比较合同

关闭 AI，限时 40 分钟。starter 能零警告编译，但第一条完整顺序 oracle 必须失败；修完一项后，后续的溢出、null 或稳定性 oracle 会继续暴露下一项。`STARTER EXPECTED FAILURE` 不是通过。

要求：

1. 调度顺序必须是优先级降序、创建时间升序、ID 升序；只反转优先级层；
2. 数值比较使用安全 compare，不使用减法或窄化强转；
3. dueAt 字段为 null 时放末尾，不能只包装整个 WorkOrder；
4. 窄比较器只比较 priority，使同组元素依靠稳定排序保留输入顺序；
5. 返回不可修改排序副本，不改变 source；
6. 独立循环比较器故障仍应产生 `CYCLIC_ORDER`；
7. 最终输出 `exercise.assertions=14 passed` 和 `EXERCISE PASS`。

```bash
cd exercises/encyclopedia/ch.java-engineering.sorting-comparators
./verify.sh
```

变更题：加入固定 `evaluationTime` 下的 overdue 主键。不能在 comparator 内调用当前时间；新增截止恰好等于 evaluationTime 与 null dueAt 的边界测试。
