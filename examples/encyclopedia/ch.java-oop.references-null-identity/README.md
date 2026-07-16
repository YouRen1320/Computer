# 示例：引用、身份、别名与 null 观察台

这个示例把 `Device` 当成已经提供的“对象盒子”，只观察引用规则，不要求此时理解盒子的类声明。先预测输出，再运行：

```bash
cd examples/encyclopedia/ch.java-oop.references-null-identity
./verify.sh
```

固定观察点：

1. `primary` 与 `alias` 保存指向同一对象的引用，因而 `primary == alias` 为 `true`；
2. 经 `alias` 修改对象状态后，经 `primary` 能看到新状态；
3. `sameState` 的字段内容相同，但它是另一次 `new` 创建的对象，身份不同；
4. `missing` 保存 `null`，不指向对象；先判断再访问不会失败；
5. `NullDereferenceFailure` 故意对 `null` 解引用，必须非零退出。

验证脚本精确比对正常输出，并确认故障进程出现 `NullPointerException`。它不会把对象地址、哈希码或 JVM 内存布局当作稳定证据。
