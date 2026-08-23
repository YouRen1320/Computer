# 示例：final 绑定与不可变对象观察台

示例用可变盒子证明 final 引用不冻结对象，用 `Money.plus` 证明变化返回新值，并用原始类型数组证明输入、输出两侧都需要防御性复制。

~~~bash
cd examples/encyclopedia/ch.java-oop.final-immutability
./verify.sh
~~~

验证器比较完整输出，还要求 final 重赋值真实编译失败、未复制输入数组真实导致运行失败。成功末行是 `EXAMPLE PASS`。
