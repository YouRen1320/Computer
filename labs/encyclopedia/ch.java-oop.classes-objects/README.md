# 实验：FactoryCare 两个设备实例

本实验用同一个 `Device` 类创建 `pump` 与 `sensor` 两个实例。两者拥有同名字段和同一组方法，但每个实例保存自己的字段状态。

```bash
cd labs/encyclopedia/ch.java-oop.classes-objects
./verify.sh
```

先写预测表：

| 操作 | pump.code | pump.status | sensor.code | sensor.status |
| --- | --- | --- | --- | --- |
| 两个实例赋初值后 | ? | ? | ? | ? |
| `pump.activate()` 后 | ? | ? | ? | ? |
| `sensor.rename("TEMP-08")` 后 | ? | ? | ? | ? |
| `sensor.deactivate()` 后 | ? | ? | ? | ? |

验收条件：

1. 两个实例的最终状态精确匹配，且修改一个实例不会串到另一个实例；
2. `DeviceObjectsOracle` 在 `-ea` 下输出 `assertions=10 passed`；
3. 局部变量遮蔽故障能编译，却必须以非零状态退出；
4. 故障证据明确指出 `expected=TEMP-08 actual=SENSOR-07`；
5. 最后一行打印 `LAB PASS`。

这不是构造器实验：对象创建后再逐项赋字段是本章刻意保留的过渡写法。如何保证对象一出生就有效，下一章再解决。
