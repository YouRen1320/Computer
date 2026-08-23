# 独立练习：消除 raw type 并恢复 PECS 合同

关闭 AI，限时 35 分钟。starter 的业务结果与复制方法使用 raw type，普通编译看似可运行，但 `-Xlint:all -Werror` 会拒绝它。

要求：

1. 把 raw `Result` 改为 `Result<Device>`，删除不必要的业务强转；
2. 把 raw copy 改为泛型方法，source 为 producer，target 为 consumer；
3. 保留从 `List<RepairTicket>` 到 `List<WorkItem>` 和 `List<Object>` 的两次合法复制；
4. 不使用 raw type、双重强转或 `@SuppressWarnings`；
5. 让 `WrongTargetFailure.java` 继续编译失败；
6. 最终输出 `exercise.assertions=10 passed`。

```bash
cd exercises/encyclopedia/ch.java-engineering.generics-type-safety
./verify.sh
```

初始版本应打印 `STARTER EXPECTED FAILURE`，说明 raw/unchecked 警告被门禁拦住。完成后打印 `EXERCISE PASS`。先写下 copy 两个参数的读写操作，再决定 extends 与 super，不要靠交换关键词碰运气。

变更题：增加 `InspectionTicket`，把它复制进同一个 `List<WorkItem>`；新增三条断言且保持零警告。
