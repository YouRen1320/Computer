# 泛型 Repository 结构替换示例

示例定义 `Repository[T]` Protocol、Python AI 侧拥有的不可变 `PrioritySuggestion`，以及无需
显式继承的 `MemoryRepository`。服务只把建议标为已审，不修改 Java 拥有的工单状态。
验证器运行锁定的 mypy 正/负类型夹具、运行时合同测试，并检查类型注解仍保留 `T` 关系。

```bash
./verify.sh
```

本入口固定执行 mypy 2.3.0；它不等于 pyright、跨版本或跨服务契约已经通过。
