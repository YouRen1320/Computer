# 示例：流与资源所有权观察台

示例用跟踪型内存流验证 UTF-8 普通/空文本、二进制字节、借用型接口和读取/关闭同时失败。所有资源事件都可直接断言，不依赖操作系统句柄或网络。

~~~bash
cd examples/encyclopedia/ch.java-engineering.io-resource-lifecycle
./verify.sh
~~~

运行前预测输入/输出是否关闭、借用流是否仍可用，以及两个 close 失败在 suppressed 中的顺序。验证器还会重放吞错、丢 cause、未关闭与 finally 覆盖主异常。成功末行是 `EXAMPLE PASS`。
