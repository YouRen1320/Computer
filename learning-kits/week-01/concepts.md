# Week 01 系统讲义

## 1. Java 程序怎样得到反馈

```text
source (.java)
  → javac 编译
  → bytecode (.class)
  → JVM 执行
  → 程序输出/异常

test source
  → testCompile
  → JUnit/Surefire 执行
  → Tests run / Failures / Errors
```

四类证据必须分开：

1. 编译错误：语法、名称、类型或访问不成立，测试尚未运行；
2. 运行时异常：已编译，执行到某处失败；
3. 测试失败：代码运行完成但 actual 不满足 expected；
4. 构建成功：本次生命周期执行项通过，仍需看运行了多少测试。

TS 类比：`tsc` 与 Vitest 也分层；失效处是 Java package/classpath/JVM/Maven 的具体链路不同。

## 2. 源文件、package、class 与 main

```java
package com.factorycare.learning;

public class Main {
    public static void main(String[] args) {
        System.out.println("FactoryCare");
    }
}
```

- package 是命名空间；目录需与构建约定一致；
- public 顶层类通常与文件名一致；
- `main` 是经典入口：public 可被启动器访问，static 无需先创建对象，void 不返回给 JVM 一个 Java 值；
- `String[] args` 保存命令行参数，本周只读取简单位置；
- import 让名称可解析，不会安装依赖。

## 3. 外部 I/O 与方法 I/O

```java
static long totalCents(long unitPriceCents, int quantity) {
    return unitPriceCents * quantity;
}
```

这个方法有参数和返回值，但没有外部 I/O。外部 I/O 是控制台、文件、网络、数据库等边界。

```java
Scanner scanner = new Scanner(System.in);
System.out.print("单价（分）：");
long unitPrice = Long.parseLong(scanner.nextLine());
System.err.println("错误信息写到 stderr");
```

把读取/解析/输出与纯计算拆开，测试不需要伪造控制台。`Scanner.nextInt()` 与 `nextLine()` 混用有换行陷阱，本阶段优先读取整行再解析。

## 4. 值、变量与类型

八种基本类型：`byte short int long float double char boolean`。常用业务起步以 `int/long/double/boolean` 为主。

- 局部变量使用前必须初始化；
- `long` 字面量常用 `L`，`float` 用 `F`；
- `5 / 2` 两边是整数，结果是 `2`；
- `5.0 / 2` 是 `2.5`；
- `double` 有二进制浮点误差，不用于最终金额事实；
- `int` 溢出不会自动报错；
- widening 通常安全，narrowing 需要显式 cast 且可能丢失；
- `String` 是引用类型；`null` 只表示没有对象，深入处理在 Week 02。

TS 类比：两者都有静态检查；失效处是 TS 类型通常擦除到 JS，而 Java 基本类型、重载、数值宽度和字节码运行都有不同规则。

## 5. 运算与表达式

- 算术：`+ - * / %`；
- 比较：`== != < <= > >=`；
- 布尔：`&& || !`；
- 赋值：`=` 和复合赋值；
- 字符串 `+` 从左到右拼接，`"总计=" + 1 + 2` 得到 `总计=12`；
- 不确定优先级时加括号；
- `&&/||` 会短路，本周只观察，不设计复杂条件。

金额实验使用“分”的 long，并写清负数、0、乘法溢出策略。

## 6. 方法、参数与返回

```java
static long calculateTotalCents(long unitPriceCents, int quantity) {
    return Math.multiplyExact(unitPriceCents, quantity);
}
```

逐项：修饰符、static、返回类型、名称、参数类型/名、方法体。

- argument 是调用时提供的值，parameter 是声明中的接收变量；
- Java 永远按值传递；引用类型参数也是复制“引用值”；
- `return` 结束当前方法并可带回值；
- `void` 不返回业务值；
- 重载看名称+参数列表，不能只改返回类型；
- package-private 可让同 package 测试访问，没必要为测试把所有方法 public；
- 一个方法应有清晰输入、输出和失败契约。

## 7. JUnit 是行为证据

```java
@Test
void calculatesTotalCents() {
    long actual = OrderAmountCalculator.calculateTotalCents(1999, 3);
    assertEquals(5997, actual);
}
```

AAA：Arrange 输入/依赖，Act 调用，Assert 业务事实。Expected 来自业务规则，不应复制实现表达式。

最低测试类型：

- normal：常规输入；
- boundary：0、上限或临界点；
- invalid：负数/非法字符串；
- failure mechanism：溢出或解析异常。

`assertThrows` 要验证抛出时机和必要消息/类型。测试通过只证明覆盖到的例子，不证明所有输入。

## 8. 第一周复杂度意识

本周方法主要是 O(1)：固定数量的算术和判断与输入规模无关。读取命令行文本的实际成本与字符数有关，但不把 I/O 细节做算法考核。Week 02 才系统分析数组单次扫描 O(n)。

## 常见误区

- 把 return 叫“控制台输出”；
- 只看到 BUILD SUCCESS，不看 Tests run；
- 使用 double 表示金额且没有误差契约；
- 通过 cast 让错误类型“能编译”；
- 把 static 理解成必须跟 public/private；
- 为了测试把业务方法全部 public；
- Scanner 和业务规则写在同一个超长 main。
