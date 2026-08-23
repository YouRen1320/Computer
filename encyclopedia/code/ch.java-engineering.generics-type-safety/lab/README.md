# 实验：FactoryCare 泛型类型安全边界

实验实现 `Result<T>` 和 PECS 复制方法。正常源码必须在 `-Xlint:all -Werror` 下零警告编译，运行后输出输入、操作、结果与 12 个断言。四个故障文件分别验证不变性、错误 producer、错误 consumer 与 raw type 警告。

运行前完成读写表：

| 参数类型 | 可读为 | 可写入 | 理由 |
| --- | --- | --- | --- |
| `List<T>` | ? | ? | ? |
| `List<?>` | ? | ? | ? |
| `List<? extends T>` | ? | ? | ? |
| `List<? super T>` | ? | ? | ? |

```bash
cd labs/encyclopedia/ch.java-engineering.generics-type-safety
./verify.sh
```

验收条件：

1. 正例零 raw/unchecked 警告，精确输出 `assertions=12 passed`；
2. `List<RepairTicket>` 可复制到 `List<WorkItem>` 与 `List<Object>`；
3. `Result<Device>` 读取无需业务强转；
4. 四个错误源码都必须非零编译；若任一意外成功，实验失败；
5. 最终输出 `LAB PASS`。

变更练习：增加 `InspectionTicket implements WorkItem`，从 `List<InspectionTicket>` 复制到现有 WorkItem 目标，不改 copy 方法体；新增三条断言。修复故障时禁止 raw type、双重强转和宽范围 `@SuppressWarnings`。
