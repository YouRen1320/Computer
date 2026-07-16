# 实验：FactoryCare 顺序集合调度、撤销与发布边界

实验把同一批工单放进四种可观察关系：List 保留输入与重复，Queue 产生 FIFO 调度，Deque 产生 LIFO 撤销，view/copy 分别表现源联动与稳定浅快照。Oracle 固定执行 18 个断言；四个故障程序分别证明遍历结构修改、空队列异常读取、不可修改集合写入和非法索引。

运行前写下预言：

| 场景 | 输入 | expected | 选择的合同/API |
| --- | --- | --- | --- |
| 调度 | WO-201/202/203 | ? | ? |
| 撤销 | assign-1/2/3 | ? | ? |
| 空队列 | 无元素 | ? | ? |
| 发布后源追加 | RECEIVED/VALIDATED，再追加 ASSIGNED | view=?，snapshot=? | ? |
| 删除取消项 | KEEP/CANCEL/CANCEL/KEEP | ? | ? |

```bash
cd labs/encyclopedia/ch.java-engineering.sequential-collections
./verify.sh
```

验收条件：

1. 正例在 JDK 25 下零 lint 警告，输出 `assertions=18 passed`；
2. 插入与遍历顺序、FIFO 和 LIFO 都与三元素预言一致；
3. 空 `poll`/`peek` 返回 null，没有意外异常；
4. 不可修改 view 和 snapshot 都拒绝经自身引用修改，但只有 view 看见源列表后续追加；
5. 四个故障程序必须非零退出并出现对应异常类；
6. 最终输出 `LAB PASS`。

变更练习：为调度增加“跳过取消项但保留原始输入 List”的要求，不修改调用者传入列表；新增相邻两个取消项、全取消和空输入断言。不要 catch 并忽略集合异常。
