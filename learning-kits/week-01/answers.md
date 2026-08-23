# Week 01 收束参考

在学习者完成第一次迁移尝试后按需读取。本文件提供映射和审查锚点，不用于制造普通周百分制分数。

## 从金额示例到维修估价

| 原示例 | 迁移任务 |
| --- | --- |
| `unitPriceCents` | `hourlyRateCents` |
| `quantity` | `laborHours` |
| 单价 × 数量 | 配件费 + 时薪 × 工时 |
| `OrderAmountCalculator` | `RepairEstimateCalculator` |
| 两个命令行参数 | 三个命令行参数 |

真正的新变化是多了一个 `partsCostCents` 输入和一次 exact 加法；package、经典 main、字符串解析、纯计算分层与 stdout 模式都可以迁移，不需要重新发现。

## 纯计算参考

一种足够清晰的实现：

```java
package com.factorycare.learning;

public class RepairEstimateCalculator {
    public static long calculateEstimateCents(
            long partsCostCents,
            long hourlyRateCents,
            int laborHours
    ) {
        long laborCostCents = Math.multiplyExact(
                hourlyRateCents,
                (long) laborHours
        );
        return Math.addExact(partsCostCents, laborCostCents);
    }
}
```

本周不要求在这里处理负数。`multiplyExact` 防止人工费乘法静默溢出，`addExact` 防止最终相加静默溢出；二者都属于运行时失败，不是编译失败。

## CLI 映射

合格的脚手架应保留这些职责：

- 参数数量检查：CLI 边界；
- `Long.parseLong`：两个金额文本；
- `Integer.parseInt`：工时文本；
- 调用 `calculateEstimateCents`：进入纯业务规则；
- `System.out.println("estimateCents=" + estimateCents)`：成功输出；
- 解析错误写 stderr：外部输入失败，不在业务类打印。

具体错误文案和退出码不是本次迁移核心，只要沿用现有一致做法即可。

## 聚焦测试参考

如果新类作为正式源码保留，一条正常规则测试已经能补足最主要的新行为：

```java
@Test
void calculatesPartsAndLaborEstimate() {
    long result = RepairEstimateCalculator.calculateEstimateCents(
            5_000L,
            2_000L,
            3
    );

    assertEquals(11_000L, result);
}
```

现有 `OrderAmountCalculatorTest` 已经证明 `long` 大金额和乘法溢出模式，不需要为新类机械复制所有旧测试。若未来这项规则进入真实业务，再按负数合同、加法溢出和 CLI 错误风险扩展。

## 通过判断

结论为 `证据通过` 时应同时看到：

- 能解释原示例与新任务的结构映射；
- 能说明 3—4 个 TODO 为什么这样补；
- `mvn test` 和代表性 CLI 是实际运行结果；
- 能指出至少一个本次未验证项；
- 不要求记住具体退出码、重做四类故障或从空项目重写。

## 面试校准

合格回答应短而具体：说明 main 是适配层、字符串在边界解析、纯方法不做 I/O、Java 参数按值传递、整数除法与溢出风险、JUnit 只证明实际执行的断言。若只说“Java 强类型”或照读代码，再用一个相似输入变化追问，而不是增加冷门定义题。
