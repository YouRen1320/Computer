# 私有参考实现：异常失败契约

参考实现把输入校验放在目标 try 之外，让 checked 冲突继续传播，并将未知 gateway 异常转换为带 cause 的应用异常。最小 AutoCloseable 证明反向关闭和 suppressed。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.exceptions-failure-contracts
./verify.sh
~~~

成功末行是 `SOLUTION PASS`。该目录仅用于教师核验，不应由公开材料引用。
