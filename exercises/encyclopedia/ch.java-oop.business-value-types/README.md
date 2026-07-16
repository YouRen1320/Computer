# 练习：修复三个业务值边界

起始代码可以编译，但依次隐藏了三项缺陷：金额从 double 建立、工单号正则过宽、当地时间读取系统默认时区。请把输入政策收回值类型，保持固定测试数据和退出码不变。

要求：

1. Money 从十进制文本建立，明确两位尺度与舍入/拒绝政策；
2. WorkOrderId 只接收 `WO-` 加规范 UUID，并调用标准解析器；
3. ServiceTime 必须接收显式 ZoneId，不能靠 `systemDefault()`；
4. 正常输出不随运行机器、当前时间或 locale 改变。

~~~bash
cd exercises/encyclopedia/ch.java-oop.business-value-types
./verify.sh
~~~

未修复时应看到 `STARTER EXPECTED FAILURE status=8`。修复时先处理第一条证据，再让下一故障暴露，不要同时重写全部类型。
