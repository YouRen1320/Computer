# Week 01 系统讲义

## 1. Java 程序如何变成反馈

最小链路：

```text
WorkOrderPriorityCalculator.java
  → javac 做语法/类型检查并生成 .class
  → java 或测试插件启动 JVM
  → JVM 加载字节码并执行
  → 正常结果 / 运行时异常 / JUnit 断言失败
```

三类反馈必须区分：

| 类型 | 发生阶段 | 例子 | 第一证据 |
| --- | --- | --- | --- |
| 编译错误 | 执行前 | 类型不匹配、缺少符号、语法错误 | 编译器文件、行号、错误信息 |
| 运行时异常 | 某条执行路径 | 数组越界、显式非法输入 | 异常类型、message、堆栈首个业务帧 |
| 测试失败 | 测试已运行 | expected 与 actual 不同 | 失败测试名、断言差异、输入 |

不要从输出最后一行开始猜。优先找**最早且与你代码相关**的错误，再构造最小复现。

## 2. 源文件、类、package 与 import

- package 是命名空间和可见性边界的一部分；
- public 顶级类名必须与源文件名一致，否则编译器会拒绝；
- import 只是让类型名书写更短，不会“复制代码”；
- `main` 是一种程序入口，JUnit 测试并不要求业务类都有 `main`；
- 表达式产生值，语句完成动作，代码块限定作用域。

### 与 ES module 的类比

package/import 可粗略类比 TypeScript module/import，都是组织和引用名称的手段。

类比失效：Java package 与目录、编译、访问控制、类全限定名有自己的规则；它不等同于 npm package，也没有 TypeScript 那套路径别名/运行时模块解析语义。

## 3. 控制台输入输出与方法输入输出

Java程序常见的经典入口是：

```java
public static void main(String[] args) {
    System.out.println("FactoryCare");
}
```

- `String[] args`接收启动程序时传入的命令行参数；
- `System.out`是标准输出，`print/println/printf`负责写出文本；
- `System.err`是标准错误输出，适合与正常结果区分；
- `System.in`是标准输入流；入门阶段可用`Scanner`把文本解析成字符串或数字。

最小控制台输入示例：

```java
import java.util.Scanner;

public class ConsoleIoDemo {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.print("请输入设备名称：");
        String equipmentName = scanner.nextLine();

        System.out.println("设备：" + equipmentName);
    }
}
```

这里存在两种不同的“输入输出”：

- 控制台I/O从程序外部读取或写出数据，可能失败、阻塞或包含不可信输入；
- 方法的参数和返回值只是代码内部调用契约，本身不代表访问了控制台、文件或网络。

例如`calculateTotalCents(int unitPriceCents, int quantity)`有方法输入和返回值，但它没有外部I/O，是容易测试的纯计算。后续会把控制台读取与业务计算分开，避免在核心规则中直接调用`Scanner`。

JDK 25也支持更简化的启动形式和`IO.println`。现有IDEA示例使用了这类新语法；本阶段先掌握企业代码、旧项目和主流文档中更常见的经典`main`与`System.out`，再认识简化形式。`Scanner.nextInt()`后紧接`nextLine()`的换行问题、字符编码和资源关闭会在相应实验及Week 04 I/O中继续处理。

## 4. 八种基本类型

| 类型 | 用途直觉 | 关键风险 |
| --- | --- | --- |
| `byte` | 8位整数/原始数据 | 算术常提升为int |
| `short` | 较小整数 | 很少作为业务默认 |
| `int` | 默认整数 | 溢出静默回绕 |
| `long` | 更大整数 | 字面量常需 `L` |
| `float` | 单精度浮点 | 字面量常需 `F`，精度低 |
| `double` | 默认浮点 | 不能精确表达许多十进制小数 |
| `char` | UTF-16 code unit | 不一定等于一个用户可见字符 |
| `boolean` | 真/假 | 不能当0/1整数 |

JavaScript/TypeScript 的 `number` 通常是双精度浮点；Java 把多种数值表示分开。迁移时最容易犯的错是把业务数量、精确金额、百分比都随手用 `double`，或忽略 `int / int` 仍为整数除法。

### 溢出、提升与转换

- 较小整数参与算术时常提升为 `int`；
- widening conversion 通常不丢表示范围，narrowing conversion 可能截断；
- 强制转换只是让编译器接受，不证明业务值安全；
- `Math.addExact` 等方法可在需要时把整数溢出变成异常；
- 精确业务金额后续应使用合适的十进制类型，不用浮点。

示例思考：`5 / 2` 是 `2`；`5 / 2.0` 才是浮点结果。先问业务要整数商、四舍五入还是精确比例，不要只“修成能过”。

## 5. 基本类型、引用类型与 null

基本类型变量直接保存该基本值。对象/数组/String 变量保存一个**引用值**；`null` 表示没有引用目标。基本类型不能为 `null`。

包装类型如 `Integer` 可以为 `null`，还涉及自动装箱/拆箱。本周只需认识风险：

```java
Integer count = null;
// int next = count + 1; // 自动拆箱时会抛出 NullPointerException
```

### TypeScript 类比与失效

TS 开启 strict null checks 后也能约束 `null/undefined`，这有助于理解空值应进入类型/契约。

失效处：Java 没有与 JS `undefined` 完全相同的普通引用值；Java 数组和对象字段有默认值，而局部变量必须先赋值；TypeScript 类型通常在编译后擦除，Java 类型与 JVM 运行模型不同。

## 6. `var` 不是动态类型

`var` 只允许编译器从局部初始化表达式推断静态类型：

```java
var severity = 3;       // 静态类型仍是 int
var code = "HIGH";     // 静态类型仍是 String
```

它不能用于字段、没有初始化器的局部变量或让变量稍后随意变类型。只有当右侧使类型一眼可见且不损害业务语义时使用。

## 7. String：不可变、内容与身份

`String` 对象不可变：所谓拼接、替换、trim 都产生或返回一个字符串结果，不会原地修改原字符串。

- `==` 对引用类型比较两个引用值是否指向同一对象；
- `equals` 表达字符串内容相等；
- 字符串常量池可能让某些 `==` 代码偶然为真，更危险；
- `null`、`""`、`"   "` 是三个不同概念；
- 对可能为 null 的变量调用方法会抛异常，应先明确契约，而不是到处补判空。

### 与 JavaScript 的关键差异

JS 中字符串是 primitive，`===` 按字符串值比较；Java `String` 是引用类型，内容比较用 `equals`。把 TS 的 `===` 习惯翻译成 Java `==` 是高频错误。

`char` 也不能被理解为“任意一个字符”。某些 Unicode 字符需要两个 UTF-16 code unit。Week 02 字符串算法只做受控 ASCII 设备编码时，要写明这个输入约束。

## 8. 数组：固定长度与边界

Java 一维数组：

- 创建后长度固定；
- 下标范围为 `0..length-1`；
- 元素有默认值；
- 数组本身是引用类型；
- 访问越界在运行时抛 `ArrayIndexOutOfBoundsException`。

与 JS Array 不同，Java 数组不是动态列表，不能 `push`，也不会自动扩容。多个元素的动态组织在 Week 03 学集合。

遍历的循环不变量示例：在处理下标 `i` 之前，区间 `[0, i)` 的元素已经按规则检查完成。写出不变量能帮助发现 `<= length` 之类边界错误。

## 9. 运算符与短路

- `&&` 和 `||` 短路：左侧足以决定结果时不执行右侧；
- `&`、`|` 对 boolean 也可运算，但不短路，本周业务条件优先 `&&/||`；
- 运算优先级容易误读时加括号；
- 复合赋值可能隐含转换，不能用来掩盖类型问题；
- 浮点 `==` 容易受表示误差影响；
- 业务规则应避免带副作用的复杂条件。

短路可用于安全守卫：先检查引用非 null，再访问它。但更好的第一步是明确参数是否允许 null。

## 10. 控制流：让业务优先级可见

### `if/else` 与早返回

守卫条件先拒绝非法输入；最高优先级规则可以早返回。这样避免深层嵌套，也让规则覆盖顺序明显。

注意：早返回不是越多越好。若多个分支互相影响，要先写决策表，避免前一个 return 让后续规则无法到达。

### `switch` 表达式

Java 25 的稳定 `switch` 表达式可以根据受控输入返回值：

```java
String label = switch (severity) {
    case 1 -> "LOW";
    case 2, 3 -> "MEDIUM";
    case 4 -> "HIGH";
    case 5 -> "CRITICAL";
    default -> throw new IllegalArgumentException("severity out of range");
};
```

本例不是完整计算器答案，只展示语法。传统 `switch` 的 fall-through 风险与 JS 相似；箭头形式避免无意贯穿。不要用 `default` 静默吞掉非法业务值。

### 循环

- `for`：已知索引或次数；
- 增强 `for`：只需依次读取数组元素；
- `while`：先判断条件，可能一次不执行；
- `do/while`：至少执行一次；
- `break` 结束循环，`continue` 跳过本次余下部分。

每个循环都应说明终止条件和边界。不要为“代码短”嵌套三元表达式或把规则压成一行。

## 11. 方法与按值传递

方法签名包含名称和参数类型等；返回类型不是重载判定的唯一差异，不能仅凭返回类型重载。

### 参数按值传递

Java 所有参数都按值传递：

- 传 `int` 时复制整数值；
- 传对象/数组时复制引用值；
- 被调方法可以通过复制的引用修改同一个可变对象内容；
- 被调方法把自己的参数重新指向新对象，不会改变调用者变量保存的引用。

JavaScript 对 primitive 和 object reference value 的调用语义可作为直觉类比，但面试中仍应准确说“值传递”，不要说 Java “对象按引用传递”。

### 方法设计

- 方法名表达业务问题；
- 参数最少且含义清晰；
- 守卫条件拒绝非法输入；
- 纯计算方法输入相同则输出相同，没有外部副作用，易测试；
- 一个方法只承担一个清楚的变化原因；
- 不通过 `boolean, boolean, boolean` 无限扩张接口，Week 02 会用对象建模。

## 12. JUnit：把规则变成可重复事实

推荐 Arrange–Act–Assert：准备输入、执行行为、验证可观察结果。测试名应包含“条件—行为—结果”。

核心工具：

- `@Test` 标记测试；
- `assertEquals` 比较期望与实际；
- `assertTrue/False` 验证布尔条件，但失败信息要有业务含义；
- `assertThrows` 同时验证异常类型，并可检查稳定 message；
- `assertAll` 聚合相关断言；
- 参数化测试适合相同规则下多组输入。

### 测试设计来源

- 等价类：每类选择代表值；
- 边界值：最小、最大、刚小于、刚大于；
- 决策表：多条件组合与优先级；
- 失败路径：非法严重度、负数量；
- 回归：每修一个真实 bug，保留能复现它的测试。

测试验证公开可观察行为，不反射调用私有方法，不把当前分支结构复制到测试里。测试先失败、实现后通过是强证据；只看一次绿色不证明测试有效。

### 与 Vitest/Jest 的类比与失效

AAA、断言、参数化、测试隔离等原则相通。失效处在于 Java 编译期类型、JUnit 生命周期、Maven/Surefire发现规则和异常断言 API 不同；不要凭前端测试 API 猜 Java 注解或 runner 行为。

## 13. 算法基础：复杂度与数组

Big-O 描述输入规模增长时操作数量或额外空间的增长级别，忽略常数不代表常数永远无关。

- 单次顺序扫描：时间 `O(n)`；
- 两层独立完整嵌套扫描：通常 `O(n²)`；
- 只保存一个最佳值：额外空间 `O(1)`；
- 创建同长度新数组：额外空间 `O(n)`。

本周数组题的合格答案必须有：输入约束、空数组策略、循环不变量、边界测试、时间/空间复杂度，以及是否修改输入。

## 常见错误

- 把 Java 当“更严格的 TypeScript”，靠猜 API；
- 用 `==` 比较字符串内容；
- 忘记整数除法和溢出；
- 用强转让错误类型“能编译”；
- 把对象参数称为“引用传递”；
- 循环条件写成 `i <= array.length`；
- `switch default` 静默返回普通值掩盖非法输入；
- 测试只有成功路径或只断言“不为 null”；
- 测试私有实现，重构就全部破坏；
- AI 生成规则后没写决策表，分支优先级互相覆盖。

## 官方资料

- [Java SE 25 Language Updates](https://docs.oracle.com/en/java/javase/25/language/)
- [Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/)
- [JLS 25](https://docs.oracle.com/javase/specs/jls/se25/html/)
- [JLS：Types, Values, and Variables](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html)
- [JLS：Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html)
- [JUnit User Guide](https://docs.junit.org/current/user-guide/)
- [Maven Surefire Plugin](https://maven.apache.org/surefire/maven-surefire-plugin/)

接下来完成[实验](./labs.md)，不要先读答案册。
