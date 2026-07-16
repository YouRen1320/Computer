# 私有校准：通知继承与组合

仅在独立尝试后核对。答案保留稳定父契约，短信和邮件子类用 `super` 增加渠道前缀；`WorkOrderNotifier` 通过 private final 字段组合依赖。十个断言覆盖父类型替换、两个依赖、非法输入和宿主不成为格式器子类型。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.inheritance-composition
./verify.sh
~~~

验证器还运行加强前置条件故障，并编译一个 `@Override` 拼写错误；二者都必须按预期失败。
