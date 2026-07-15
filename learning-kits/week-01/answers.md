# Week 01 独立答案册

> **警告：考前勿看。** 以下是[无 AI 考核](./assessment.md)的一种参考思路，不是唯一实现。先比较你的决策表和测试证据，再看代码差异。

## A. 规则顺序参考

一种清楚顺序：

1. 校验严重度和受影响数量；
2. 安全风险直接得到 `CRITICAL`；
3. 根据严重度得到基础级别；
4. 应用停机最低 `HIGH`；
5. 设备数至少 10 升一级；
6. 24 小时重复再升一级；
7. 每次升级都封顶 `CRITICAL`。

数量升级和重复升级可以叠加，因为题目写的是“原规则计算完成后再升级”。例如严重度 1、非停机、影响 10 台、重复：`LOW → MEDIUM → HIGH`。若你选择不叠加，便与题意不符。

决策表至少包括：

| severity | downtime | safety | count | repeated | 期望 |
| ---: | --- | --- | ---: | --- | --- |
| 1 | false | false | 1 | false | LOW |
| 2 | false | false | 1 | true | HIGH |

注意上表只展示两行：严重度 2 的基础是 MEDIUM，只应用重复一次应为 HIGH；还必须确认该行没有触发数量升级。完整答案要另外写 9/10 边界、安全、最高级、两次升级和非法输入。

## B. 参考实现

```java
package com.factorycare.workorder;

public final class WorkOrderPriorityCalculator {
    public String calculate(
            int severity,
            boolean downtime,
            boolean safetyRisk,
            int affectedEquipmentCount,
            boolean repeatedWithin24Hours) {
        validate(severity, affectedEquipmentCount);

        if (safetyRisk) {
            return "CRITICAL";
        }

        String priority = basePriority(severity);
        if (downtime && severity >= 3 && rank(priority) < rank("HIGH")) {
            priority = "HIGH";
        }
        if (affectedEquipmentCount >= 10) {
            priority = upgrade(priority);
        }
        if (repeatedWithin24Hours) {
            priority = upgrade(priority);
        }
        return priority;
    }

    private void validate(int severity, int affectedEquipmentCount) {
        if (severity < 1 || severity > 5) {
            throw new IllegalArgumentException("severity must be between 1 and 5");
        }
        if (affectedEquipmentCount < 1 || affectedEquipmentCount > 1000) {
            throw new IllegalArgumentException(
                    "affectedEquipmentCount must be between 1 and 1000");
        }
    }

    private String basePriority(int severity) {
        return switch (severity) {
            case 1 -> "LOW";
            case 2, 3 -> "MEDIUM";
            case 4 -> "HIGH";
            case 5 -> "CRITICAL";
            default -> throw new IllegalStateException("validated severity changed");
        };
    }

    private String upgrade(String priority) {
        return switch (priority) {
            case "LOW" -> "MEDIUM";
            case "MEDIUM" -> "HIGH";
            case "HIGH", "CRITICAL" -> "CRITICAL";
            default -> throw new IllegalArgumentException("unknown priority: " + priority);
        };
    }

    private int rank(String priority) {
        return switch (priority) {
            case "LOW" -> 1;
            case "MEDIUM" -> 2;
            case "HIGH" -> 3;
            case "CRITICAL" -> 4;
            default -> throw new IllegalArgumentException("unknown priority: " + priority);
        };
    }
}
```

这是 Week 01 的过渡实现。字符串和 `rank` 重复揭示了 Week 02 引入 enum 的真实动机；不要在本周提前用 enum，也不要把这段代码当最终架构。

更精简的实现可以用一个 `ensureAtLeastHigh` 方法避免 `rank`，只要规则仍清晰。若实现把所有条件压成一条三元表达式，即使结果正确，也不应拿满可维护性分。

## C. 测试关键点

示例：

```java
@Test
void repeatedFaultUpgradesMediumToHigh() {
    var result = calculator.calculate(2, false, false, 1, true);
    assertEquals("HIGH", result);
}

@Test
void repeatedFaultDoesNotExceedCritical() {
    var result = calculator.calculate(5, false, false, 1, true);
    assertEquals("CRITICAL", result);
}

@Test
void safetyRiskOverridesOtherInputs() {
    var result = calculator.calculate(1, false, true, 1, false);
    assertEquals("CRITICAL", result);
}

@Test
void zeroAffectedEquipmentIsRejected() {
    var error = assertThrows(
            IllegalArgumentException.class,
            () -> calculator.calculate(1, false, false, 0, false));
    assertTrue(error.getMessage().contains("affectedEquipmentCount"));
}
```

还要有 `count=9/10`、`severity=0/6`、两次升级叠加、停机最低级别和最高上限。测试动态返回字符串时仍使用 `assertEquals`，不要用 `==`。

## D. 故障定位要点

- `> 10` 应由 count=10 的边界测试杀死；
- `==` 可能因字符串池偶然通过；本题必须让调用方传入 `new String("HIGH")` 等运行时对象，才能稳定证明“内容相同但身份不同”。计算器当前返回字面量，不能拿它与同一字面量比较后声称已经杀死该故障。生产判断始终用 `equals`，Week 02 后优先使用 `Priority` enum；
- 升级越过 `CRITICAL` 应由上限测试杀死；
- `<= length` 对空数组或循环到末尾时抛越界，堆栈指向访问行。

合格记录必须保留故障发生时的失败测试，而不是只写“发现一个 bug”。

## E. 数组算法参考

```java
public static int longestSevereRun(int[] severities) {
    if (severities == null) {
        throw new IllegalArgumentException("severities must not be null");
    }

    int longest = 0;
    int current = 0;
    for (int severity : severities) {
        if (severity < 1 || severity > 5) {
            throw new IllegalArgumentException("severity must be between 1 and 5");
        }
        if (severity >= 4) {
            current++;
            longest = Math.max(longest, current);
        } else {
            current = 0;
        }
    }
    return longest;
}
```

循环不变量：处理完前 `k` 个元素后，`current` 是以第 `k-1` 个元素结尾的严重段长度，`longest` 是前 `k` 个元素中最长严重段。时间 `O(n)`，额外空间 `O(1)`，不修改输入。

测试：空数组、全轻微、全严重、开头/中间/末尾严重段、长度1、非法0/6、null策略。

## F. 口述校准

- Java 所有参数按值传递；对象参数复制引用值；
- `String ==` 比引用身份，`equals` 比内容；
- `int / int` 为整数除法，强转发生时机不对仍无法恢复已丢小数；
- `&&` 左侧为 false 时右侧不执行，不应把重要副作用藏在条件中；
- 等价类减少重复样例，边界值抓阈值错误，决策表抓多条件组合与覆盖顺序；
- `O(n)` 描述时间随输入长度线性增长，`O(1)` 额外空间不随输入规模增长。

## 常见错误

- 修改方法签名却漏掉旧调用方；
- 安全分支在输入校验前返回，导致非法数量被静默接受；
- 两项升级只执行一次；
- `CRITICAL` 再升级产生未知字符串；
- 参数化测试样例多但没覆盖边界；
- 算法测试只覆盖 `[4, 5]`，未验证段被轻微值重置。

## 面试校准

> 先提交[面试题](./interview.md)的独立回答再阅读。下列要点需要连接你自己的代码和失败证据。

1. **源码执行**：javac 做语法/类型检查并生成字节码，JVM 加载执行。某个测试方法已经运行说明相关代码已编译，但构建还可能有其他模块、阶段或测试失败，不能直接说整个构建成功。
2. **基本类型**：byte、short、int、long、float、double、char、boolean。浮点不能精确表示很多十进制小数，金额需要明确精度和舍入的十进制方案。
3. **var**：只做有初始化器的局部静态类型推断，不是动态类型。右侧类型不直观或业务语义被隐藏时使用显式类型。
4. **三种空**：null 是没有引用目标，空字符串长度为 0，空白字符串含空白字符。按业务在入口建立契约，不靠散落判空或静默规范化掩盖问题。
5. **String 相等**：`==` 比引用身份，`equals` 比内容；字符串池使某些字面量比较偶然为 true。稳定失败实验使用 `new String("HIGH")` 等运行时对象，不能用计算器返回的同一字面量证明。
6. **整数除法**：两个 int 先得到整数商；至少一个操作数必须在除法前转成浮点。事后强转无法恢复已截断小数。
7. **值传递**：Java 始终按值传递。数组/对象参数复制引用值，两个引用可指向同一可变对象，因此能改元素；把形参重新指向新对象不会改变调用者变量。
8. **数组**：Java 数组元素类型和长度固定，元素有默认值；合法末下标是 length-1，访问 length 会运行时越界。它不是 JS 的动态 Array。
9. **switch/if**：离散互斥映射常用 switch 更清晰；多条件覆盖关系可能更适合守卫和决策表。default 返回普通值可能掩盖非法或未来变化，应按契约拒绝或利用穷尽性。
10. **短路**：`&&/||` 在左侧决定结果时不执行右侧。把重要副作用放右侧会让动作次数依赖条件并难以测试，应显式表达。
11. **多条件测试**：先写决策表，覆盖每条规则、交叠、阈值边界、非法输入和覆盖顺序。全排列可能冗余；选择能区分规则的代表组合并保留回归。
12. **assertThrows**：断言具体异常类型，必要时检查稳定业务信息。只断言 Exception 可能让 NullPointerException 等意外错误也通过。
13. **私有方法测试**：优先测试公开可观察行为，避免与实现耦合。复杂私有逻辑可能提示职责应提取为可测试协作者或纯函数，但不为测试暴露无意义 API。
14. **循环不变量**：每轮前后保持成立的事实。最长严重段中，处理完前 k 项后 current 表示以当前前缀末端结尾的严重段长度，longest 表示已处理前缀最大值。
15. **复杂度**：单次扫描时间 O(n)。创建与输入同长的新数组是额外空间 O(n)；严重度固定 1—5 的长度 5 数组相对输入 n 是 O(1)，必须说明规模参数。
16. **AI 责任**：AI 可以给候选组合或审查，人定义规则、审 diff、运行测试、注入故障并完成无 AI 变更。只有真实发生时才说 AI 漏掉 count=10、叠加升级等边界；否则说这是准备验证的风险。

模拟项目追问：字符串是 Week 01 为聚焦语法/测试而设的过渡，重复映射与拼写风险正好形成 Week 02 引入 enum 的动机；长期模型不会保留魔法字符串。所有非法输入必须先拒绝，即使 safetyRisk 本可直接得到 CRITICAL，否则非法数据是否被接受会依赖另一个条件。
