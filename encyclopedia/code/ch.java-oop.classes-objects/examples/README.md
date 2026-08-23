# 示例：类、实例、字段与实例方法观察台

这个示例定义一个最小 `Device` 类，创建两个互不相同的实例，并用实例方法改变各自字段。它还用固定字符串构造 `Scanner`，展示 `new Scanner(...)` 与 `new Device()` 都会产生对象引用，但二者承担不同职责。

```bash
cd examples/encyclopedia/ch.java-oop.classes-objects
./verify.sh
```

运行前预测：

1. 两次 `new Device()` 是否得到同一实例；
2. `pump.activate()` 后 `sensor.status` 是否变化；
3. `sensor.rename("TEMP-08")` 中 `this.code` 指向哪个实例的字段；
4. `Scanner` 读出的两个 token 被写入哪个对象。

固定验证器精确比对七行输出，并运行一个故意把形参赋给自身的遮蔽故障。故障必须非零退出并报告字段仍是旧值。
