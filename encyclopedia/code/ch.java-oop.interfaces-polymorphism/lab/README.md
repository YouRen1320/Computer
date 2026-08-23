# 实验：FactoryCare 三渠道接口替换

实验定义 `NotificationSender`。短信和邮件通过 `ValidatingSender` 抽象模板共享校验，记录型实现直接实现接口。应用服务只保存接口依赖；三个实现逐一运行共同契约，记录型实现还证明委托参数可观察。

~~~bash
cd labs/encyclopedia/ch.java-oop.interfaces-polymorphism
./verify.sh
~~~

验收包含十五个正常断言，以及缺少接口方法的编译失败、错误强转、遗漏第三实现的类型分支、接受空白编号的契约违反四类固定故障。需求变更：新增 ConsoleSender，只增加实现和装配，不修改服务；随后说明它是否应继承 ValidatingSender。
