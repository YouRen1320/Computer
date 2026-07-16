# 私有校准：不可变 Money

仅在独立尝试后核对。答案使用 private final 字段、构造校验、币种边界和 `Math.addExact`；`plus` 返回新 Money，十个断言同时验证结果、新身份、原值与失败路径。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.final-immutability
./verify.sh
~~~
