# 私有参考实现：流与资源生命周期

参考实现区分拥有型和借用型复制，显式 UTF-8，并用 try-with-resources 保留读取主异常与关闭 suppressed。验证器重放五个故障。

~~~bash
cd solutions-private/encyclopedia/ch.java-engineering.io-resource-lifecycle
./verify.sh
~~~

成功末行是 `SOLUTION PASS`。公开材料不得引用本目录。
