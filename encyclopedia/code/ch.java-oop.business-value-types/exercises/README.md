# 练习：修复三个业务值边界
+
## 同一验证入口

只编辑本目录 `src/` 中的 starter，并始终运行 `./verify.sh`：完整 starter 精确返回 `41` 与 `EXPECTED_RED`；全部合同及独立故障夹具通过时返回 `0` 与 `EXERCISE_GREEN`；编译失败、只修了一部分、故障夹具被削弱或其他未知状态返回 `43` 并保留首个诊断。

因此修正后无需改跑私有脚本，也不要修改 `failures/`、验证器或退出码来制造绿灯。

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
