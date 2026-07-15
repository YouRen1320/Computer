# Week 01 独立答案册

仅在学习者提交考核或明确要求揭示后读取。

## 概念校准

- main：`public` 可访问，`static` 无需对象，`void` 无 Java 返回值，`String[] args` 接收参数；
- stdout/stderr 是外部副作用；return 是方法内值传递；assertion 比较 expected/actual；
- 整数除法截断小数；narrowing 可能丢失；普通 int/long 溢出会绕回，精确方法可抛异常；
- Java 按值传递；引用参数复制的是引用值；
- BUILD SUCCESS 只证明执行的构建步骤通过，需检查实际测试数量。

## 参考设计

一种清晰契约：基点分母 10000，服务费向最接近整数分舍入或向上/向下，必须事先说明。下面示例使用四舍五入到分，生产业务是否允许需由产品契约决定。

```java
package com.factorycare.learning;

final class ServiceFeeCalculator {
    private static final int BASIS_POINTS_DENOMINATOR = 10_000;

    static long serviceFeeCents(long amountCents, int rateBasisPoints) {
        if (amountCents < 0) {
            throw new IllegalArgumentException("amountCents must be non-negative");
        }
        if (rateBasisPoints < 0 || rateBasisPoints > 3_000) {
            throw new IllegalArgumentException("rateBasisPoints out of range");
        }
        long product = Math.multiplyExact(amountCents, rateBasisPoints);
        return Math.addExact(product, BASIS_POINTS_DENOMINATOR / 2)
                / BASIS_POINTS_DENOMINATOR;
    }

    static long totalCents(long amountCents, int rateBasisPoints) {
        return Math.addExact(amountCents, serviceFeeCents(amountCents, rateBasisPoints));
    }
}
```

注意：`product + 5000` 本身也可能溢出，因此使用 `Math.addExact`。若业务要求向下取整，去掉加 5000；若要求银行家舍入，需不同实现。

## 测试关键点

```java
@Test
void calculatesTenPercent() {
    assertEquals(100, ServiceFeeCalculator.serviceFeeCents(1000, 1000));
    assertEquals(1100, ServiceFeeCalculator.totalCents(1000, 1000));
}

@Test
void zeroAmountHasZeroFee() {
    assertEquals(0, ServiceFeeCalculator.serviceFeeCents(0, 3000));
}

@Test
void rejectsNegativeAmount() {
    assertThrows(IllegalArgumentException.class,
            () -> ServiceFeeCalculator.serviceFeeCents(-1, 100));
}

@Test
void rejectsRateAboveMaximum() {
    assertThrows(IllegalArgumentException.class,
            () -> ServiceFeeCalculator.serviceFeeCents(1000, 3001));
}
```

还应有：负费率、30% 边界、需要舍入的值、乘法/加法溢出、CLI 非数字。不要让 expected 调用生产方法计算。

## CLI 边界

参考职责：main/CLI 读取两行文本、调用解析方法、调用业务方法、格式化输出；捕获可向用户解释的 `NumberFormatException/IllegalArgumentException/ArithmeticException`，写 stderr，并使用有意义退出码。不要在业务类打印。

## 最低服务费变化

契约示例：`amountCents == 0` 返回 0；否则原始服务费小于 100 时返回 100。应先新增 0 金额和 1 分/低费率测试，再改一个独立方法或参数。不要复制整套计算器。

## 复杂度

所有计算是固定数量算术，时间 O(1)、额外空间 O(1)。CLI 读取文本与字符长度相关，但不是这道业务算法的规模变量。

## 评分常见扣分

- 使用 double 金额且没写误差/舍入：项目与概念扣分；
- main 内全部逻辑、无法单测：项目扣分；
- 只测一条正常路径：测试扣分；
- 用 cast 或吞异常伪造成功：关键项不通过；
- 没有真实命令输出：证据不足；
- 先改实现后补同构断言：独立修改扣分。

## 面试校准

合格回答应短而具体：说明 main 结构、I/O 与 return 分层、Java 按值传递、基本数值宽度/溢出、JUnit 与 Maven 阶段。若只说“Java 强类型、JUnit 测试”，继续追问具体日志和边界。
