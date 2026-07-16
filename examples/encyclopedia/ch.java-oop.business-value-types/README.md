# 示例：业务值观察台

示例用 `Money` 固定十进制尺度和币种，用 `WorkOrderId` 组合严格正则与 UUID 解析，用 `ServiceTime` 显式保存 Instant 和 ZoneId。所有输出使用固定输入，不读取当前时间或机器默认时区。

~~~bash
cd examples/encyclopedia/ch.java-oop.business-value-types
./verify.sh
~~~

运行前预测金额相等、跨地区显示和四个故障的结果。验证器会真实重放 double 长尾、BigDecimal 尺度误判、默认时区漂移和宽松正则误收。成功末行是 `EXAMPLE PASS`。
