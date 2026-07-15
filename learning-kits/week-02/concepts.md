# Week 02 系统讲义

## 1. String 是不可变引用对象

```java
String a = new String("PUMP");
String b = new String("PUMP");
```

`a == b` 比较引用值，通常 false；`a.equals(b)` 比较内容，true。不要靠字符串池偶然让 `==` 看似工作。

常用操作：`length`、`isEmpty/isBlank`、`charAt`、`substring`、`contains`、`startsWith`、`indexOf`、`split`、`strip`、`toUpperCase`。要点：

- String 不可变，方法通常返回新 String；
- `split` 接收正则，不是任意原样分隔；
- 大小写转换可能与 Locale 有关；业务 code 通常规定 ASCII/稳定格式；
- 循环拼接大量字符串考虑 `StringBuilder`；
- 解析数字可能抛 `NumberFormatException`。

## 2. null、空与缺失

- null：引用没有对象；
- `""`：长度 0 的真实字符串；
- `"   "`：空白字符串；
- 未初始化局部变量：编译器不允许读取；
- 无结果可以选择 null、异常、特殊结果或空集合；必须由契约决定。

`Objects.requireNonNull` 适合在入口快速失败，但错误信息要有上下文。不要用 `""` 替代所有缺失，也不要捕获 NPE 后继续假成功。

TS 类比：`strictNullChecks` 能提示 null/undefined；失效处是 Java 没有 undefined，且引用/基本类型、异常和 API 契约不同。

## 3. 数组是固定长度容器

```java
int[] priorities = {5, 2, 4};
int first = priorities[0];
int size = priorities.length;
```

- 索引 0 到 length-1；
- 新 `int[]` 默认 0，新引用数组默认 null；
- 数组变量保存引用，赋值不复制数组；
- `Arrays.copyOf` 复制元素引用/基本值，嵌套对象仍可能共享；
- `Arrays.equals` 比较元素，`==` 比较数组引用；
- 二维数组是数组的数组，行长度可不同；
- `ArrayIndexOutOfBoundsException` 是运行时异常。

一次完整扫描长度 n 的数组通常时间 O(n)，额外计数变量空间 O(1)。若创建同长度结果数组，额外空间 O(n)。

## 4. 条件表达业务决策

```java
if (machineStopped) {
    return 5;
} else if (affectedUsers >= 20) {
    return 4;
}
return 2;
```

- 条件必须是 boolean；
- `&&/||` 短路，可避免不安全解引用，但不要把副作用藏进去；
- 分支顺序会影响结果，先写决策表；
- early return 可减少嵌套，但返回点要清楚；
- ternary 适合一个简单值，不嵌套业务树。

switch expression 适合一个有限输入映射：

```java
int weight = switch (category) {
    case "SAFETY" -> 3;
    case "PRODUCTION" -> 2;
    case "GENERAL" -> 1;
    default -> throw new IllegalArgumentException("unknown category");
};
```

字符串 switch 要先决定 null；enum 将在 Week 04 提供更强有限集合。

## 5. 四种常用循环

```java
for (int i = 0; i < values.length; i++) { }
for (int value : values) { }
while (hasMore()) { }
do { } while (retry);
```

- index for：需要索引/邻居；
- enhanced for：只需要元素；
- while：次数未知，先判断；
- do-while：至少一次；
- break 结束最近循环，continue 跳过本次；
- return 结束整个方法，不只是循环。

常见错误：`<= length` 越界、忘记 i++ 无限循环、修改错误变量、循环体内过早 return、嵌套循环复杂度误判。

循环不变量示例：“处理到索引 i 前，count 等于前 i 个元素中 >=4 的数量”。它帮助证明循环而不是凭感觉。

## 6. 方法拆分

坏信号：超长参数列表、boolean flag 改变两套职责、同一方法解析输入/计算/打印、重复分支。

拆分原则：

- 方法名说清意图；
- 输入/输出/失败明确；
- 纯计算尽量无副作用；
- 变量最小作用域；
- 重载不是用不同返回类型；
- 不为每行代码建一个方法。

## 7. 调试器与错误定位

IDE 调试流程：

1. 用失败测试构造最小复现；
2. 在规则入口/可疑分支设断点；
3. Step Over 观察值，必要时 Step Into；
4. 看 Variables 与 Call Stack；
5. 证明第一个偏离预期的位置；
6. 写/保留回归测试，再修复。

调试器显示当前一次执行；JUnit 负责长期重复验证。

## 8. 算法基础：一次扫描

数组最大值/计数/首个匹配可以一次扫描 O(n)、空间 O(1)。若需要每个优先级计数且级别固定 1—5，可用长度 6 的 int 数组，空间仍视为 O(1)。若级别任意，Week 05 学 Map。

## 常见误区

- String 用 `==` 比内容；
- `value.trim() == ""`；
- `i <= array.length`；
- 在 for 第一轮 return；
- while 条件变量从不更新；
- switch default 静默返回 0；
- 为避免 NPE 把所有 null 转空字符串；
- 用防御性 if 堆叠代替契约。
