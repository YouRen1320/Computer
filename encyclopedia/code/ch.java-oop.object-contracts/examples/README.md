# 示例：直接观察对象契约

这个示例用不可变 `DeviceId` 直接验证身份与值相等的差别、`equals` 的五条规则、相等对象的哈希一致性，以及不泄露租户标识的 `toString`。验证只调用对象契约本身，不借助集合容器间接证明。

~~~bash
cd examples/encyclopedia/ch.java-oop.object-contracts
./verify.sh
~~~

运行前先预测两个独立创建但字段相同的对象在 `==`、`equals` 和 `hashCode` 上分别得到什么结果。验证器还会真实运行三个故障程序，并要求错误的 `@Override` 真实编译失败。成功末行是 `EXAMPLE PASS`。
