# 私有校准：NotificationSender 多态服务

仅在独立尝试后核对。答案让服务只依赖 NotificationSender，短信与邮件继承集中校验的抽象类，记录型实现直接 implements。十二个断言覆盖三实现、共同空白边界、记录参数与 null 依赖。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.interfaces-polymorphism
./verify.sh
~~~

验证器还要求错误 Email→Sms 强转产生 `ClassCastException`，并要求缺少接口方法真实编译失败。
