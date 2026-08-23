# 公开练习：让状态只能经行为改变

starter 的业务行为能通过八个断言，但 status 仍是 public，包外故障源码可以直接绕过行为。把字段收回 private，同时保持现有 public API 与断言不变。

~~~bash
cd exercises/encyclopedia/ch.java-oop.encapsulation-packages
./verify.sh
~~~

初始版本应输出 **STARTER EXPECTED FAILURE reason=public-field-still-accessible**。完成后，正常断言通过且越界源码编译失败，验证器才输出 **EXERCISE PASS**。

变更任务：新增 completeRepair，只允许从 IN_REPAIR 进入 COMPLETED；不得添加通用 setStatus。
