# 示例：接口、抽象类与动态分派观察台

`NotificationSender` 是调用契约；短信和邮件继承内部 `AuditedSender` 抽象类，记录型实现则直接实现接口。`WorkOrderNotificationService` 只持有接口字段，三个运行时对象通过同一个 `notify` 调用点产生不同结果。

~~~bash
cd examples/encyclopedia/ch.java-oop.interfaces-polymorphism
./verify.sh
~~~

运行前写出每个变量的静态类型、实际对象类和预期输出。验证器精确比对正常输出，还要求缺少接口方法真实编译失败、错误向下转型真实产生 `ClassCastException`、中央类型分支在第三实现上稳定失败。成功末行是 `EXAMPLE PASS`。
