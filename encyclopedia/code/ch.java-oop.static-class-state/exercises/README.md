# 公开练习：移除工单编号的全局可变状态

starter 的两个场景共用 `static next`：第一个场景通过，第二个场景期望独立从 `WO-0001` 开始却得到 `WO-0002`。初始验证必须输出 `STARTER EXPECTED FAILURE`。

~~~bash
cd exercises/encyclopedia/ch.java-oop.static-class-state
./verify.sh
~~~

要求把序号状态放入可创建的实例，让两个场景各自拥有编号器；保留无状态格式化方法为 static；不得增加 `resetForTest`、写死两个输出或删除故障断言。完成版本须输出 `exercise.assertions=8 passed`，验证器才会报告 `EXERCISE PASS`。

需求变更：增加 `NC` 与 `NJ` 两个站点，各自从一开始，交错调用不能串号。
