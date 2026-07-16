# 公开练习：让封闭命令变更成为编译信号

starter 已有十二状态 enum、坐标 record 和三个 sealed 命令，但坐标没有校验，处理器用 default 吞掉 `CloseCommand`。固定输入首先输出 `STARTER EXPECTED FAILURE`。

~~~bash
cd exercises/encyclopedia/ch.java-oop.enum-record-sealed
./verify.sh
~~~

要求：紧凑构造器 trim site 并拒绝非正坐标；明确处理 Assign、Start、Close 三个 case 并删除 default；验证 enum 数量/精确解析、record 身份与值相等、相等 hash、非法构造和三个命令。完成后输出 `challenge.assertions=14 passed`。

需求变更：增加 CancelCommand(reason)，先保存 non-exhaustive 编译失败，再补非空 reason 和第四分支；不实现工单状态转换或授权。
