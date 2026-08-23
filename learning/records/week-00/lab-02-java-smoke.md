# Lab 2：非 Spring Maven + JUnit 烟雾工程

- 日期：2026-07-12
- 工程：`practice/week-00-java-smoke`
- Maven 坐标：`com.factorycare.learning:week-00-java-smoke:1.0-SNAPSHOT`
- 编译目标：Java 25

## 实现与验证

- 正式代码：`src/main/java/com/factorycare/learning/OrderAmountCalculator.java`
- 测试代码：`src/test/java/com/factorycare/learning/OrderAmountCalculatorTest.java`
- 纯方法：`calculateTotalCents(int unitPriceCents, int quantity)`
- 正常值：`1999 * 3 = 5997`
- 边界值：数量为 `0` 时结果为 `0`
- IDEA JUnit Runner：2 个测试通过，Temurin 25，退出代码 0。
- Maven：`Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`。
- 干净构建：`mvn clean test` 删除 `target` 后重新编译 2 个正式源码、1 个测试源码，最终 `BUILD SUCCESS`。
- 依赖树：只有 JUnit 6.1.1 的 `test` 作用域组件；没有 Spring、Lombok、数据库或其他业务框架。

## 故障记录

| 故障 | 失败阶段 | 分类 | 最先可信的位置 | 恢复 |
| --- | --- | --- | --- | --- |
| 正式类 package 临时改为 `com.factorycare.wrong` | `testCompile` | 测试源码编译错误，不是 JUnit `Errors` | `OrderAmountCalculatorTest.java:[11,22]`，随后 `[18,22]`，找不到符号 | 恢复 `com.factorycare.learning` 后 2 个测试通过 |
| 测试期望值从 5997 临时改为 5998 | `surefire:test` | JUnit 断言失败，`Failures: 1` | `OrderAmountCalculatorTest.java:13`，`expected 5998 but was 5997` | 恢复期望值 5997 后 2 个测试通过 |
| 正式代码返回语句临时删除分号 | `compile` | 正式源码编译错误，不是 JUnit `Errors` | `OrderAmountCalculator.java:[5,41]`，需要 `';'` | 恢复分号后 `mvn clean test` 通过 |

额外故障：将乘法临时改为加法时，两个测试均成为 `Failures`；说明 `BUILD SUCCESS` 不能替代有效测试数量与断言结果。

## 可复用规则

- `src/main/java` 放正式源码，`src/test/java` 放测试源码。
- `compile`、`testCompile`、`surefire:test` 是不同阶段；前置阶段失败时后续阶段不会执行。
- 日志中的 `[ERROR]` 文本不等于 JUnit 汇总字段 `Errors`。
- `BUILD SUCCESS` 必须结合 `Tests run`、`Failures`、`Errors`、`Skipped` 判断。
- 错误堆栈中的测试行是发现不一致的位置，不一定是制造错误的根因。

