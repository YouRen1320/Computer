# Week 01 实验手册

每个实验先定义预期，再让 AI 生成或修改，最后审查并运行。已有同类证据可以直接引用，不为完成清单重复造错或重复写测试。

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

## Lab 5：JUnit 与反馈四象限（按缺口选做）

优先复用已有日志；只有某一类反馈没有真实证据时，才受控复现并恢复：

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

### 回归证据

如果已经保存过“乘法被改成加法后测试变红、恢复后全绿”的证据，直接引用；否则只在需要证明测试有效时做一次。O(1) 计算，不因数值大小增加循环。

## Lab 7：渐隐迁移与周收束（30—45 分钟）

把现有金额 CLI 当作完整示例，迁移成“配件费 + 时薪 × 工时”的维修估价 CLI。AI 提供 package、class、main、参数检查和错误处理脚手架，只留下类型/解析、纯计算和调用输出等 3—4 个关键 TODO。

学习者先说明 TODO 职责，再自行补全或指挥 AI 写入；完成后复跑现有测试，并运行一条正常和一条零工时或大金额路径。详细合同见 [assessment.md](./assessment.md)。不再追加负值、服务费或人为故障题。

## 完成清单

- [ ] G0 有计时证据；
- [ ] main/I/O 可运行；
- [ ] 数值/转换实验有预测；
- [ ] 业务方法与控制台分离；
- [ ] 四类反馈都真实复现；
- [ ] FactoryCare CLI 测试通过；
- [ ] 一次完整示例 → 渐隐补全 → 相似迁移 → 真实验证完成。
