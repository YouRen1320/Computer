# Week 01 收束：维修估价 CLI 迁移

- 日期：2026-07-26
- 模式：AI 开放、脚手架迁移
- 真实学习时间：1 小时
- 结论：证据通过

## 迁移任务

把已有订单金额 CLI 迁移为维修估价 CLI，业务规则为：

```text
estimateCents = partsCostCents + hourlyRateCents × laborHours
```

学习者完成了三个输入的数据类型选择、解析与输出映射，并能解释为什么业务计算需要先使用 `Math.multiplyExact` 计算人工费，再使用 `Math.addExact` 计算最终估价。

## 交付证据

- [RepairEstimateDemo.java](../../practice/week-00-java-smoke/src/main/java/com/factorycare/learning/RepairEstimateDemo.java)：负责参数数量检查、字符串解析、调用计算方法以及 stdout/stderr 输出；
- [RepairEstimateCalculator.java](../../practice/week-00-java-smoke/src/main/java/com/factorycare/learning/RepairEstimateCalculator.java)：负责纯业务计算，并分别检测乘法和加法溢出。

## 已验证

- `mvn test`：原有 4 条 JUnit 测试全部通过，`BUILD SUCCESS`；
- 输入 `5000 2000 3`：输出 `estimateCents=11000`，退出码 `0`；
- 输入 `5000 2000 0`：输出 `estimateCents=5000`，退出码 `0`；
- 输入 `2000000000 2000000000 3`：输出 `estimateCents=8000000000`，退出码 `0`；
- 输入 `9223372036854775807 1 1`：输出 `ERROR: estimate overflow`，退出码 `66`；
- 学习者能区分命令行入口的 I/O 职责与计算类的纯业务职责，并能说明两个精确运算分别保护的业务边界。

## 有意未做

- 未处理负金额、负工时、折扣、服务费和元格式化；这些不属于本次收束范围；
- 未为相同结构重复编写一组形式化 JUnit 测试，使用已有测试回归加代表性 CLI 运行作为比例化验证；
- 本次不是关闭 AI 的阶段门考试，不记录百分制成绩。

## 未独立验证

- 未在 IntelliJ 运行配置中再次手工执行新入口；命令行编译和运行结果已验证。
