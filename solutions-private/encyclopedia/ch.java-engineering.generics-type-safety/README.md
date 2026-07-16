# 私有解析：泛型边界挑战

只在公开 starter 留下 raw/unchecked 失败证据并自行尝试后阅读。

修复有两个核心：`Result<Device>` 把成功值类型保持到读取点，所以不需要业务强转；`copy` 用同一个 T 连接 `List<? extends T>` 与 `List<? super T>`，让 RepairTicket 来源可以写入 WorkItem 或 Object 目标。

```bash
cd solutions-private/encyclopedia/ch.java-engineering.generics-type-safety
./verify.sh
```

固定验证器要求正例 `-Xlint:all -Werror` 零警告、10 个断言通过，并确认不兼容目标仍在编译期失败。私有解不能被公开教材或 starter 引用。
