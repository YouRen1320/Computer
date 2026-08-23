# 独立练习：维修材料费与分摊守恒

先关闭 AI，限时 25 分钟。公开目录只给题目、起始代码和可观察预期，不给实现表达式。

`src/MoneyChallenge.java` 中有四个故意错误的占位值：`totalCents`、`eachCents`、`remainderCents`、`conserved`。只替换这四个右侧表达式，不新增方法，不改变输入。

固定输入：

- 配件单价：2,500 分；
- 数量：3；
- 上门费：1 分；
- 分摊组数：4。

要求：

1. 总额先将一个乘法操作数提升为 `long`，再加上门费；
2. 使用 `/` 计算每组整数分；
3. 使用 `%` 保存余数；
4. 使用比较表达式验证守恒式；
5. 运行后应输出 `totalCents=7501`、`eachCents=1875`、`remainderCents=1`、`conserved=true`。

验证命令：

```bash
cd exercises/encyclopedia/ch.java.expressions-conversions
rm -rf build && mkdir -p build/classes
javac --release 25 -d build/classes src/MoneyChallenge.java
java -cp build/classes MoneyChallenge
```

修改练习：把 `serviceFeeCents` 改为 3，再次手算、预测、运行；记录哪些输出改变，守恒式是否仍为 `true`。

故障练习：临时移除乘法前的 `long` 提升，并把单价改为 `1_073_741_824`、数量改为 2。解释第一个可信证据为何是负的 `totalCents`，然后恢复代码。完成自己的尝试前不要查看私有解析。
