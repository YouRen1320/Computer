# 数组边界观察台

该示例只依赖 JDK 25。它展示一维数组的 `length` 与索引遍历、别名修改、线性查找、不等长二维数组，以及 `String[] args` 的零项和多项边界。

运行前先预测：长度 3 的合法索引；alias 修改索引 1 后原数组的值；最大值和第一个 4 的索引；三行二维数组各自的长度；无参数时 args 是否为 null。

```bash
cd examples/encyclopedia/ch.java.arrays-command-args
./verify.sh
```

脚本会精确核对无参数和两个参数的输出，再运行一个故意把 `length` 当最后索引的程序。该程序必须非零退出并出现 `ArrayIndexOutOfBoundsException`；这是预期失败证据，不应删除。
