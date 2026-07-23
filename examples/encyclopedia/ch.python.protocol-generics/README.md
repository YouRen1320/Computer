# 泛型 Repository 结构替换示例

示例定义 `Repository[T]` Protocol、不可变 WorkOrder 和无需显式继承的 MemoryRepository。验证器运行合同测试并检查类型注解仍保留 `T` 关系。

```bash
./verify.sh
```

标准库运行通过不等于 mypy/pyright 已通过；类型检查器是单独的未执行门禁。
