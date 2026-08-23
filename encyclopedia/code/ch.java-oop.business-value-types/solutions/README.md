# 私有参考实现：业务值边界

参考实现从十进制文本创建 Money，严格解析带前缀 UUID，并让 ServiceTime 的 ZoneId 成为显式组成部分。验证器重放四个指定故障，确认修复没有删除失败证据。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.business-value-types
./verify.sh
~~~

成功末行是 `SOLUTION PASS`。该目录只用于教师核验，不应被公开练习引用。
