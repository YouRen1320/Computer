# 公开练习：把伪 is-a 通知服务改成组合

starter 让 `WorkOrderNotifier` 继承 `SmsFormatter`，并在子类中只接受 `URGENT`。父格式器接受 `NORMAL`，所以固定父契约输入会输出 `STARTER EXPECTED FAILURE`。

~~~bash
cd exercises/encyclopedia/ch.java-oop.inheritance-composition
./verify.sh
~~~

要求：保留一个接受 `NORMAL` 与 `URGENT` 的普通父格式器；实现短信和邮件两个重写子类并使用 `super`；让通知服务通过 private final 字段组合格式器；同一个服务源码通过构造参数切换两个依赖。完成后输出 `challenge.assertions=10 passed`。不得删除父契约输入、把 NORMAL 改成 URGENT，或只把退出码改为零。

需求变更：新增夜班格式器，不修改通知服务；然后写三句话说明为何通知服务不是短信格式器。
