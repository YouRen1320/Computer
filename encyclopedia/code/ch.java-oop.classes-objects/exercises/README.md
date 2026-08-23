# 独立练习：定义并操作两个设备实例

关闭 AI，限时 30 分钟。初始程序能编译，但方法把参数或局部变量改掉，没有把结果写回当前实例的字段。

要求：

1. 保留 `Device` 类的 `code`、`status`、`repairCount` 三个字段；
2. `startRepair()` 把当前实例状态改为 `IN_REPAIR`，并让当前实例次数加一；
3. `rename(String code)` 把处理后的参数写入当前实例字段；
4. 创建 `pump` 和 `sensor` 两个实例，分别操作，证明状态互不串扰；
5. 正确结果打印 `exercise.assertions=10 passed`。

```bash
cd exercises/encyclopedia/ch.java-oop.classes-objects
./verify.sh
```

初始版本应打印 `STARTER EXPECTED FAILURE`，完成后应打印 `EXERCISE PASS`。修复前先解释每个同名标识符表示字段、参数还是局部变量；不要用复制粘贴整类来绕开 `this`。

变更练习：增加 `completeRepair()`，只改变接收者状态，不重置次数。对两个实例交错调用并新增至少三条断言。
