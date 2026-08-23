# 私有参考实现：DeviceId 对象契约

参考实现让 `tenantId` 与 `value` 同时参与 `equals` 和 `hashCode`，并让 `toString` 只显示安全的设备值。验证器直接检查五条相等规则、相等哈希与脱敏文本，同时重放三个运行故障和一个编译故障。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.object-contracts
./verify.sh
~~~

成功末行是 `SOLUTION PASS`。该目录用于教师核验，不应由公开练习直接引用。
