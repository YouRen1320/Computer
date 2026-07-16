# `@RequiresRole` 元注解契约参考解

答案只在提交练习后核对。参考解让重复注解与容器同时具备兼容的 `TYPE`/`METHOD` 目标、`RUNTIME` 保留和 `@Inherited` 类继承策略，并保留缺省 `TENANT` 元素值。

```bash
cd solutions-private/encyclopedia/ch.java-engineering.annotations-metadata
./verify.sh
```

成功输出 `PRIVATE SOLUTION PASS`。这只验证语言与运行时元数据契约，不代表已经实现鉴权框架。
