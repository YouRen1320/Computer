# 示例：继承、重写、super 与组合观察台

示例先让 `SmsFormatter`、`MailFormatter` 重写普通父类的 `render`，再让 `WorkOrderNotifier` 通过字段持有格式器。固定输入证明父类型用例可接收子类、`super` 保留基础审计前缀，且宿主不改代码即可更换组合依赖。

~~~bash
cd examples/encyclopedia/ch.java-oop.inheritance-composition
./verify.sh
~~~

运行前预测直接子类调用、父类型引用调用以及两个组合对象的五行结果。验证器还要求三类故障真实发生：拼错重写方法必须编译失败，子类加强前置条件和遗漏 `super` 必须以固定消息非零退出。成功末行是 `EXAMPLE PASS`。
