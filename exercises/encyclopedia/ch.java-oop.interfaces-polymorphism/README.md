# 公开练习：删除实现类型分支

starter 已定义 `NotificationSender` 和三个实现，但服务把依赖保存为 `Object`，并只识别短信、邮件。注入 `RecordingSender` 会稳定输出 `STARTER EXPECTED FAILURE`。

~~~bash
cd exercises/encyclopedia/ch.java-oop.interfaces-polymorphism
./verify.sh
~~~

要求：服务字段和构造参数改为 NotificationSender；`notify` 只调用接口 `send`，不使用强转、`instanceof`、类名字符串或实现专用方法；三个实现运行共同正常与空白输入契约；记录型实现证明参数被正确委托。完成代码输出 `challenge.assertions=12 passed`。

需求变更：增加 ConsoleSender，只改实现和装配。再让短信与邮件可选择继承一个集中校验的抽象类，记录型实现保持直接 implements，并说明为何调用端不受影响。
