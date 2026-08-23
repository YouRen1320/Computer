# 实验：FactoryCare 通知继承与组合

实验用一个普通 `NotificationFormatter` 父类定义固定输入契约，短信与邮件子类通过 `super` 保留基础工单前缀。`WorkOrderNotifier` 不继承任何渠道，而是组合格式器；记录型格式器证明宿主传递的工单号可观察且依赖可独立更换。

~~~bash
cd labs/encyclopedia/ch.java-oop.inheritance-composition
./verify.sh
~~~

验收包含十四个正常断言、一个构造链编译失败，以及“子类拒绝父类合法优先级”“子类遗漏基础审计”两个固定运行失败。需求变更：新增夜班格式器，不修改 `WorkOrderNotifier`；随后说明共同空白校验应位于稳定父契约还是独立协作者。
