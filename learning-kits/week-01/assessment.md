# Week 01 连贯收束：维修估价 CLI

## 目的

使用现有金额 CLI 作为完整示例，把同一组 Java 基础迁移到一个相似但不相同的小程序。这里检验的是能否看懂模式并完成关键变化，不是从空文件背代码，也不是再做一套百分制考试。

## 规则

- 建议时间：30—45 分钟；AI、项目源码和官方文档始终可用；
- 直接复用 `practice/week-00-java-smoke`，不重复已经完成的造错、退出码背诵和同类测试练习；
- AI 先展示现有金额 CLI 的整体映射，再生成带少量 TODO 的新程序脚手架；
- 学习者先说明 TODO 应承担的职责，可以自己输入，也可以让 AI 按决定写入；
- 结论只有 `证据通过` 或一个明确缺口，不计算百分数；
- 不测试 Week 02 的循环/数组，也不引入对象模型或 Spring。

## 完整示例

先把当前实现看成一条完整链路：

```text
CommandLineArgsDemo.args
  → Long.parseLong / Integer.parseInt
  → OrderAmountCalculator.calculateTotalCents
  → Math.multiplyExact
  → stdout 或明确失败
```

现有四个 JUnit 测试与已经运行过的大金额 CLI 结果直接作为基线，不重新制作。

## 渐隐迁移任务

新增一个最小“维修估价”CLI：

```text
输入：partsCostCents hourlyRateCents laborHours
规则：estimateCents = partsCostCents + hourlyRateCents × laborHours
示例：5000 2000 3 → estimateCents=11000
```

约束：

- 金额使用 `long`，工时使用 `int`；
- 纯计算与命令行输入输出分离；
- 乘法和加法都不能静默溢出；
- package、class、经典 `main`、参数数量检查和解析错误外壳由 AI 提供；
- 只留下 3—4 个有学习价值的 TODO，例如类型选择、解析映射、纯计算表达式和调用/输出；
- 不要求本周处理负数、格式化元、折扣或服务费。

## 真实验证

只做以下证据：

1. 完成 TODO 后运行 `mvn test`，确认原有回归仍全绿；
2. 运行 `5000 2000 3`，得到 `estimateCents=11000`；
3. 再选择零工时或大金额中的一条代表路径；
4. 指出入口、解析边界、纯业务方法和 exact 运算所在位置；
5. 说清一项已经验证的结论和一项本次没有验证的结论。

如果保留新的纯计算类，AI 可以生成一条聚焦正常规则的测试；不为凑数量复制现有四类测试。

## 通过证据

- 能把原金额示例的结构映射到维修估价，而不是逐字复制；
- 3—4 个关键 TODO 的职责与实现一致；
- 现有测试和代表性 CLI 真实运行；
- 能区分外部文本边界与纯计算规则；
- 没有把 AI 的推测当成已运行结果。

若某项缺失，只补该项；不退回旧版 120 分钟无 AI 考卷。
