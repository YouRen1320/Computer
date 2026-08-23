# 私有校准：受限状态、坐标与命令

仅在独立尝试后核对。答案保留十二状态 enum，坐标 record 规范化并校验，sealed 命令由 Assign、Start、Close 三个 record 穷尽处理；十四个断言覆盖有限集合、值相等、非法构造与全部分支。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.enum-record-sealed
./verify.sh
~~~

验证器还要求新增 Cancel 但漏 case 时真实编译失败，并重放非标准状态拼写的运行失败。
