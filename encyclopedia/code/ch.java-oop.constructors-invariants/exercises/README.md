# 公开练习：关闭半合法设备窗口

starter 故意留下三处问题：同名参数未写入字段、文本没有规范化、非法输入没有在构造边界拒绝。先预测首个失败，再逐项完成 TODO。

~~~bash
cd exercises/encyclopedia/ch.java-oop.constructors-invariants
./verify.sh
~~~

初始状态必须报告 **STARTER EXPECTED FAILURE**；完成后精确报告 **challenge.assertions=10 passed** 与 **EXERCISE PASS**。

变更任务：新增带显式初始状态的构造入口，只允许 REGISTERED 与 IDLE，并委托到原主构造器，不能复制 code/name 校验。
