# Week 01 实验手册

每个实验先预测，再运行；保存命令、关键日志和自己的解释。

## Lab 0：G0 实操桥接（30—45 分钟）

1. 运行现有两条 `OrderAmountCalculatorTest`；
2. 逐词解释 package、class、static、返回类型、参数和 return；
3. 把一个 int 调用参数改成 String，预测失败阶段；
4. 执行 `mvn test`，记录 compiler goal、文件/行列和消息；
5. 恢复并复验；记录真实用时。

验收：不能补造时间；能说明为什么没有 `Tests run`。

## Lab 1：经典 main 与三种输出（60 分钟）

建立 `Main`，读取 `args[0]`（先确保提供），分别输出 stdout、stderr 和 exit 前说明。

故障：文件名与 public class 不一致、package 错误、缺分号。分别判断 compile 位置。

## Lab 2：Scanner 与边界分层（75 分钟）

```text
控制台文本 → parse → 纯业务方法 → 格式化输出
```

读取单价/数量；非法文本在 CLI 层给出明确错误，业务方法只接收数值。不要在业务方法 new Scanner。

测试：纯方法无需真实 stdin；CLI 可先用小适配方法测试解析。

## Lab 3：数值、转换与溢出（90 分钟）

预测并验证：

- `5 / 2` 与 `5.0 / 2`；
- int 最大值加 1；
- long 到 int cast；
- `"total=" + 1 + 2`；
- `Math.multiplyExact` 超界。

写表格：表达式、预测、实际、规则、业务风险。

## Lab 4：方法边界（75 分钟）

把一个同时读取、计算、打印的 `main` 拆为：

- `parseNonNegativeLong`；
- `parseNonNegativeInt`；
- `calculateTotalCents`；
- `formatCents`；
- main 只编排。

解释每个输入、输出、副作用和异常。

## Lab 5：JUnit 与反馈四象限（90 分钟）

依次制造并恢复：

1. 生产代码缺分号 → compile；
2. 测试引用错误类名 → testCompile；
3. 解析非法文本 → runtime exception；
4. expected 改错 → test failure；
5. 恢复 → 2 tests/更多测试、0 failures/errors。

保存最先可信位置和为什么不看最后一大段泛化消息。

## Lab 6：FactoryCare CLI 金额计算器（3—4 小时）

### 契约

- 输入：单价分、数量；
- 正常输出：总分和格式化元；
- 单价/数量不能为负；数量 0 返回 0；
- 超出 long 范围抛明确异常；
- 纯计算与控制台适配分离。

### 测试

- 1999 × 3 = 5997；
- 1999 × 0 = 0；
- 负单价/负数量；
- 最大边界和溢出；
- 非数字 CLI 输入。

### 故障注入

把乘法改加法，确认至少两个测试红；恢复后重跑。O(1) 计算，不因数值大小增加循环。

## Lab 7：关闭 AI 的规则变化（60—90 分钟）

二选一：

- 增加固定服务费（分），明确何时为 0；
- 增加百分比服务费，明确单位与舍入。

先写契约/测试，再修改。AI 关闭；完成后口述输入到证据链。

## 完成清单

- [ ] G0 有计时证据；
- [ ] main/I/O 可运行；
- [ ] 数值/转换实验有预测；
- [ ] 业务方法与控制台分离；
- [ ] 四类反馈都真实复现；
- [ ] FactoryCare CLI 测试通过；
- [ ] 独立改动和复述完成。
