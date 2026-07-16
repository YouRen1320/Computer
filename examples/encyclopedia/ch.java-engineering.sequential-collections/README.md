# 示例：List 顺序、FIFO、LIFO、视图与快照

示例用三个可区分元素同时证明 List encounter order、ArrayDeque 的 FIFO/LIFO、空队列特殊值、迭代器安全删除，以及 `Collections.unmodifiableList` 视图与 `List.copyOf` 快照的差异。另一个故障程序在单线程 foreach 中直接修改 ArrayList，必须以 `ConcurrentModificationException` 失败。

运行前预测：

1. 输入 `[WO-101, WO-102, WO-101]` 的 size 与遍历顺序；
2. `offerLast` 后 `pollFirst` 和连续 `push/pop` 各自的离开顺序；
3. 空 ArrayDeque 的 `poll`/`peek` 返回什么；
4. 源列表追加后，view 与 snapshot 的 size 各是多少；
5. foreach 中删除当前元素时，异常由哪一步检测。

```bash
cd examples/encyclopedia/ch.java-engineering.sequential-collections
./verify.sh
```

验证器要求 JDK 25、`-Xlint:all -Werror` 零警告、正例精确输出 10 行；故障程序必须非零退出且 stderr 出现 `ConcurrentModificationException`。`EXAMPLE PASS` 只证明固定合同，不证明学习完成。
