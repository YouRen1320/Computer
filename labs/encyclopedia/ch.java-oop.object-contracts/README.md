# 实验：建立 DeviceId 契约报告

实验把 `DeviceId` 视为不可变、租户感知的值对象。正常程序逐条验证 `equals`、`hashCode` 与脱敏 `toString`，并输出记录输入、操作和结果的固定报告。所有 oracle 都直接观察方法结果，不让容器替你下结论。

~~~bash
cd labs/encyclopedia/ch.java-oop.object-contracts
./verify.sh
~~~

先预测 20 条断言是否全部成立，再运行验证器。验证器会另外重放字段集合不一致、继承导致不对称、空值处理错误、诊断文本泄密和错误重写签名。成功末行是 `LAB PASS`。
