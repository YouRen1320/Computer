# 示例：异常与失败契约观察台

示例让工单创建分别产生成功、unchecked 输入错误、checked 冲突和保留 cause 的系统失败，再用最小 AutoCloseable 观察反向关闭与 suppressed。它不依赖任何具体 I/O 资源。

~~~bash
cd examples/encyclopedia/ch.java-oop.exceptions-failure-contracts
./verify.sh
~~~

运行前预测每个 catch 分支及资源事件。验证器还会重放空 catch、丢 cause、输入误分类、finally return 吞错，以及未处理 checked 异常的真实编译失败。成功末行是 `EXAMPLE PASS`。
