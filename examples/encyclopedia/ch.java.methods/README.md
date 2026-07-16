# 方法契约观察台

该示例只依赖 JDK 25，在同一 class 中使用 `static` 小方法。它展示参数与返回值、重载、基本类型按值传递、数组引用值按值传递，以及有明确 base case 的最小递归。

运行前先预测金额 1999×0/3、优先级 3/5、两个标签重载、调用 increase 后调用者 int、数组元素修改与形参重新赋值、倒计时 0/1/4。

```bash
cd examples/encyclopedia/ch.java.methods
./verify.sh
```

脚本精确核对十二行输出，并在固定小线程栈的独立 JVM 中运行一个故意没有 base case 的递归探针。探针必须非零退出且含 `StackOverflowError`。
