# 公开练习：让 Money 的相加不修改旧值

starter 的 `cents` 是 public，`plus` 原地修改接收者并返回 `this`。结果金额看似正确，但旧 Money 已从 5000 变成 5750。初始验证必须输出 `STARTER EXPECTED FAILURE`。

~~~bash
cd exercises/encyclopedia/ch.java-oop.final-immutability
./verify.sh
~~~

要求把字段收回 private final，在构造器拒绝负值和空币种，`plus` 校验币种并返回新 Money；完成代码须有十个断言，包含结果、身份、两个输入旧值和非法输入。不得只把期望改成 5750、复制后再回写原对象或删除旧值断言。

需求变更：增加 `minus`，结果不能为负，并证明 base 在成功和失败路径后都未变化。
