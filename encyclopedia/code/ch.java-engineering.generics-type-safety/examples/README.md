# 示例：泛型关系、PECS 与擦除边界

示例用 `Result<T>` 保留成功值类型，用 `copy(List<? extends T>, List<? super T>)` 连接生产者和消费者。固定验证器还执行三类反例：不变性赋值编译失败、向 extends 视角写入编译失败、raw type 产生警告并把错误延迟到 `ClassCastException`。

运行前预测：

1. `Result.success(device)` 的 T 从哪里推断；
2. `List<RepairTicket>` 为什么不能赋给 `List<WorkItem>`；
3. 为什么复制到 `List<Object>` 合法；
4. raw type 的错误写入时是否立即抛异常；
5. `List<?>` 在运行时能否证明元素都是 String。

```bash
cd examples/encyclopedia/ch.java-engineering.generics-type-safety
./verify.sh
```

正例必须在 JDK 25 下以 `-Xlint:all -Werror` 零警告编译并精确输出六行。两个编译失败片段必须非零退出；raw type 片段必须产生警告且运行时非零。`EXAMPLE PASS` 只证明这些固定关系，不证明学习完成。
