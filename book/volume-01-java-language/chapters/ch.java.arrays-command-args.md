---
schema_version: 2
edition: 2026.2-draft
id: ch.java.arrays-command-args
title: 数组、二维数组、查找与命令行参数
responsibility: 教授固定长度序列和索引边界，以命令行参数作为输入但不引入泛型集合
volume: '01'
order: 7
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.arrays-command-args.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.loops
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释数组、二维数组、查找与命令行参数的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-arrays
  - java-array-use
  covers_topics:
  - java.array-declaration
  - java.index-length-boundary
  - java.two-dimensional-array
  - java.array-traversal-search
  - java.command-line-args
  - java.empty-input-boundary
  uses_capabilities:
  - java.control-flow
  - java.values-types-string
  - java.arrays
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从命令行参数构造优先级数组，完成遍历、最大值查找和二维班次表访问，并显式处理空数组
  covers_topic_groups:
  - java-arrays
  - java-array-use
  covers_topics:
  - java.array-declaration
  - java.index-length-boundary
  - java.two-dimensional-array
  - java.array-traversal-search
  - java.command-line-args
  - java.empty-input-boundary
  uses_capabilities:
  - java.control-flow
  - java.values-types-string
  - java.arrays
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 length 当最后索引、空参数直接访问和二维行列颠倒，定位数组边界日志并修复
  covers_topic_groups:
  - java-arrays
  - java-array-use
  covers_topics:
  - java.array-declaration
  - java.index-length-boundary
  - java.two-dimensional-array
  - java.array-traversal-search
  - java.command-line-args
  - java.empty-input-boundary
  uses_capabilities:
  - java.control-flow
  - java.values-types-string
  - java.arrays
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 数组、二维数组、查找与命令行参数

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《for、while、计数、累积与哨兵循环》](ch.java.loops.md)：独立完成数组与索引、遍历与参数前，必须先具备「for、while、计数、累积与哨兵循环」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文与配套程序可以试读、运行和修改，但脚本通过不代表学习者已经掌握，也不会自动更新 `PROGRESS.md`。

上一章的循环能把一段动作重复 N 次，但数据仍散落在多个变量里。如果 FactoryCare 一次拿到五个工单优先级，继续写 `priority1`、`priority2`、`priority3` 会让遍历、查找和边界检查迅速失控。**数组**把一组同类型值放进一个固定长度、按位置访问的容器；循环负责移动位置，数组负责保存每个位置的值。

数组最重要的不是方括号语法，而是一个永远成立的边界：对长度为 `length` 的一维数组，合法索引只有 `0` 到 `length - 1`。`length` 是元素个数，不是最后一个索引。空数组的长度是 0，因此根本没有合法索引。多数数组故障都可以回到这三个事实定位。

本章只学习固定长度数组、一维与最小二维访问、遍历、线性查找、别名、`String[] args` 和越界诊断。不引入 `List`、泛型、Stream、排序算法、对象建模或复杂输入校验。版本基线为 **JDK 25**，官方规范复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内说清元素类型、长度、索引区间、空数组、二维数组、别名、遍历、查找和命令行参数；给出一个越界反例。
2. **构建证据**：从固定命令行参数构造优先级数组；对空、单项、多项分别遍历并查找最大值；访问一个二维班次表；输出固定结果。
3. **诊断证据**：分别注入 `values[values.length]`、空参数直接读 `args[0]`、二维行列颠倒，记录异常类型、源码位置和最小修复，再完整复跑。

配套入口：

- [数组边界观察台](../../../examples/encyclopedia/ch.java.arrays-command-args/README.md)
- [0、1、N、别名与二维边界实验](../../../labs/encyclopedia/ch.java.arrays-command-args/README.md)
- [公开独立练习：工单优先级批次](../../../exercises/encyclopedia/ch.java.arrays-command-args/README.md)

公开练习保留故障起始代码。先保存预测和首次输出，再修复；私有解析不得复制进公开教材、提交记录或搜索索引。

## 2. 直觉模型：一排编号从 0 开始的储物格

把 `int[] priorities = {3, 5, 2};` 想成一排三个储物格：

```text
索引        0    1    2
元素值      3    5    2
元素个数 priorities.length = 3
合法条件    0 <= index && index < priorities.length
```

变量 `priorities` 不是“三个独立整数的别名集合”，而是指向整个数组值的引用。`priorities[1]` 表示先找到该数组，再取索引 1 的格子。索引从 0 开始，所以第二个元素的索引是 1；最后一个元素的索引是 `length - 1`，这里是 2。

这个模型要同时保留“数量”和“位置”两个概念。仓库有 3 个格子，不代表存在编号 3 的格子；编号是 0、1、2。把 `length` 当最后索引会编译成功，却在运行到该访问时抛出 `ArrayIndexOutOfBoundsException`。

## 3. 声明、创建、初始化是三个动作

最常见的完整写法：

```java
int[] priorities = new int[3];
```

可以拆成：

```java
int[] priorities;
priorities = new int[3];
```

`int[]` 是变量类型，表示“指向 int 数组”；`priorities` 是变量名；`new int[3]` 创建一个长度为 3 的数组。创建后每个 int 元素先是默认值 0：

```java
System.out.println(priorities[0]); // 0
priorities[0] = 4;
System.out.println(priorities[0]); // 4
```

已知所有初值时，可以使用数组初始化器：

```java
int[] priorities = {3, 5, 2};
String[] statuses = {"ASSIGNED", "IN_PROGRESS"};
```

数组的元素类型固定。`int[]` 只能放 int 值，不能把 String 放进去；`String[]` 保存 String 引用。编译器会阻止明显的元素类型不兼容，但不会替你证明索引在运行时一定合法。

### 3.1 方括号跟在类型后

Java 也允许 `int priorities[]`，但本书统一写 `int[] priorities`，因为 `[]` 描述的是变量的类型。多个变量写在同一声明中时，旧式写法更容易误读：

```java
int[] first, second; // 两个都是 int[]
```

为了可读性，真实业务代码仍建议一个声明只承担一个清楚职责，而不是把多个数组挤在一行。

### 3.2 长度创建后不再改变

数组长度在创建时确定。后续能修改元素，却不能把同一个数组从 3 格扩成 4 格：

```java
int[] values = new int[3];
values[0] = 9; // 改元素，长度仍是 3
```

变量可以改为指向另一个新数组，但那是“换一个数组”，不是原数组变长：

```java
values = new int[4];
```

原有三个元素不会自动搬到新数组。需要动态增减长度的业务通常使用集合，属于后续章节；当前先掌握固定边界。

## 4. `length` 是字段，不带圆括号

数组长度写作 `values.length`，不是 `values.length()`。String 的长度使用 `text.length()`，数组的长度使用字段 `length`；二者形式不同。不要让 IDE 自动补全替代概念判断。

三个最低边界：

```java
int[] empty = new int[0];
int[] one = {7};
int[] many = {7, 4, 9};

System.out.println(empty.length); // 0
System.out.println(one.length);   // 1
System.out.println(many.length);  // 3
```

对应合法索引：

| 数组 | length | 合法索引 | 最后索引 |
| --- | ---: | --- | --- |
| empty | 0 | 无 | 不存在 |
| one | 1 | 0 | 0 |
| many | 3 | 0、1、2 | 2 |

“最后索引等于 `length - 1`”只有在数组非空时才对应一个可访问位置。空数组中 `length - 1` 为 -1，-1 仍然非法。因此访问第一个或最后一个元素前，要先证明 `length > 0`。

## 5. 读取与写入都受同一个索引边界约束

读取：

```java
int first = priorities[0];
```

写入：

```java
priorities[2] = 4;
```

二者都必须满足 `0 <= index && index < priorities.length`。负数非法，等于 length 也非法。数组不会因为“只是读取”就返回一个默认的缺失值，也不会因为“只是写入”就自动扩容。

索引表达式在运行时计算，所以以下代码能通过编译：

```java
int index = priorities.length;
System.out.println(priorities[index]);
```

编译器只知道 index 是 int，不知道这次值一定越界；JVM 在真正访问时检查并抛出异常。第一可信位置通常是异常栈中第一个属于你源码的 `文件名:行号`。

## 6. 一维数组的执行过程

观察：

```java
int[] priorities = {3, 5, 2};
int index = 1;
int before = priorities[index];
priorities[index] = 4;
int after = priorities[index];
```

执行顺序：创建长度 3 的数组并写入 3、5、2；index 得到 1；检查 1 是否落在 `[0, 3)`；读取值 5；再次检查索引并把该格写成 4；最后读出 4。数组状态从 `[3,5,2]` 变为 `[3,4,2]`，其他索引没有变化。

调试数组时不要只打印最终总和。至少记录 `index`、`length`、访问前值和访问后值：

```text
event=array-write index=1 length=3 before=5 after=4
```

日志足以定位边界和错误位置，同时避免打印真实设备密钥、手机号或大批量生产数据。

## 7. 用标准 for 遍历所有索引

数组遍历最稳定的索引形式：

```java
for (int i = 0; i < priorities.length; i++) {
    System.out.println("index=" + i + " value=" + priorities[i]);
}
```

循环不变量可以表述为：每轮开始时，`0 <= i <= length`；若条件为真，则进一步得到 `i < length`，所以 `priorities[i]` 合法；本轮结束后 i 增 1。退出时 i 等于 length，所有合法索引恰好各访问一次。

逐轮表：

| 判断前 i | `i < 3` | 本轮访问 | 更新后 |
| ---: | --- | --- | ---: |
| 0 | true | priorities[0] | 1 |
| 1 | true | priorities[1] | 2 |
| 2 | true | priorities[2] | 3 |
| 3 | false | 不访问 | — |

把条件改成 `i <= priorities.length` 会多进入一轮，并尝试访问索引 3。把初值改成 1 会漏掉第一个元素。数组遍历的 0 起点和 `< length` 是由合法索引区间推导出来的，不是需要死背的仪式。

### 7.1 空数组自动执行零轮

当 length 为 0，第一次判断 `0 < 0` 为 false，循环体不执行。这通常正是“没有数据就不处理”的正确行为。若循环后需要最大值，则还必须单独定义空数组策略，因为“零轮”没有产生最大值。

### 7.2 增强 for 读取每个元素

只关心值、不需要索引时，可以写：

```java
for (int priority : priorities) {
    System.out.println(priority);
}
```

它按顺序读取每个元素，空数组执行零轮。这里的 `priority` 是本轮局部变量；给它重新赋值不会改回数组元素：

```java
for (int priority : priorities) {
    priority = 0; // 只改本轮变量
}
```

需要修改指定格、报告索引或并行访问多个数组时，使用普通索引 for 更清楚。不要为了“语法更短”丢失业务所需的位置证据。

## 8. 计数、求和、最大值与线性查找

### 8.1 计数与求和

```java
int urgentCount = 0;
int total = 0;

for (int priority : priorities) {
    total += priority;
    if (priority >= 4) {
        urgentCount++;
    }
}
```

空数组会得到 count=0、total=0，这两个初值具有明确的单位含义。累加仍可能溢出；金额与生产级溢出策略在专门章节处理，本章只用很小的固定值。

### 8.2 非空数组的最大值

```java
if (priorities.length == 0) {
    System.out.println("max=NONE");
} else {
    int max = priorities[0];
    for (int i = 1; i < priorities.length; i++) {
        if (priorities[i] > max) {
            max = priorities[i];
        }
    }
    System.out.println("max=" + max);
}
```

先处理空边界，才能合法读取索引 0。max 不能随意初始化为 0，因为数组可能全是负数；用第一个实际元素建立候选值更可靠。循环从索引 1 开始，因为索引 0 已用于初始化。

循环不变量：每轮开始时，max 是索引 `[0, i)` 中的最大值。检查索引 i 后，这个事实扩展到 `[0, i]`。退出时范围覆盖整个数组。

### 8.3 查找目标

```java
int target = 4;
int foundIndex = -1;

for (int i = 0; i < priorities.length; i++) {
    if (priorities[i] == target) {
        foundIndex = i;
        break;
    }
}
```

`-1` 作为“未找到”哨兵是安全的，因为合法索引不可能为负。找到后 break 返回第一个匹配位置；若需求是找最后一个或所有匹配，规则必须改变。这里的算法是从左到右逐项检查，最坏检查 length 次；不引入排序或二分查找。

## 9. 数组变量、别名与“Java 永远按值传递”的预告

```java
int[] first = {3, 5, 2};
int[] alias = first;
alias[1] = 4;
System.out.println(first[1]); // 4
```

赋值没有复制三个元素，而是把 `first` 中保存的**引用值**复制给 alias。两个变量随后指向同一个数组，所以通过任意一个变量修改元素，另一边都能观察到。这种关系叫 alias（别名）。

可以画成：

```text
first ----\
           >  同一个 [3, 4, 2]
alias ----/
```

不要误说“两个变量内存地址完全一样”或“Java 引用按引用传递”。当前只需要掌握：变量赋值复制的是引用值；数组对象仍只有一个。下一章讲方法参数时，会继续证明参数同样按值传递。

### 9.1 真正独立复制元素

在不引入集合和工具 API 的前提下，可以手工创建同长度数组并逐项复制：

```java
int[] copy = new int[first.length];
for (int i = 0; i < first.length; i++) {
    copy[i] = first[i];
}
copy[1] = 9;
```

此时 copy 与 first 指向不同数组，改 copy[1] 不影响 first[1]。审查需求时先问“需要共享后续修改，还是需要独立快照”，再决定别名还是复制。无意识别名会让远处代码改变当前结果。

## 10. `null` 与空数组不是一回事

```java
int[] absent = null;
int[] empty = new int[0];
```

empty 指向一个真实存在、长度为 0 的数组，可以安全读取 `empty.length`，也能安全遍历零轮。absent 没有指向数组，读取 `absent.length` 会抛出 `NullPointerException`。本章不展开空值设计，只要求不要把“没有数组”和“有一个空数组”混成同一事实。

命令行入口中的 `args` 由 JVM 提供；正常启动 `main` 且没有命令行参数时，args 是长度 0 的数组，而不是 null。因此最先检查的是 `args.length`。

## 11. 二维数组其实是“数组的数组”

```java
String[][] shifts = {
    {"Alice", "Bo"},
    {"Chen"}
};
```

外层数组长度为 2，`shifts[0]` 是第一行数组，长度为 2；`shifts[1]` 是第二行数组，长度为 1。访问分两次检查：先检查 row 是否小于 `shifts.length`，再检查 column 是否小于 `shifts[row].length`。

```java
System.out.println(shifts[0][1]); // Bo
System.out.println(shifts[1][0]); // Chen
```

Java 二维数组不要求每行等长，这种结构常称为不规则数组。不能用 `shifts[0].length` 代表所有行长度，也不能交换行列后期待自动纠正。

### 11.1 安全遍历二维数组

```java
for (int row = 0; row < shifts.length; row++) {
    for (int column = 0; column < shifts[row].length; column++) {
        System.out.println("row=" + row + " column=" + column
                + " value=" + shifts[row][column]);
    }
}
```

外层循环保证 row 合法，内层每次读取当前行自己的 length。先写出坐标含义：在 FactoryCare 班次表中，row 可以代表班次，column 代表该班次人员。若需求把两个维度反过来，变量名、数据布局和输出契约都要一起变化。

### 11.2 三个二维边界

1. 外层长度为 0：没有任何行，不能读 `matrix[0]`。
2. 某一行长度为 0：该行存在，但没有列。
3. 各行长度不同：某列在第一行合法，不代表在第二行也合法。

本章不教授矩阵运算。二维数组只用于建立“每一层都有自己的边界”这一模型。

## 12. `String[] args`：进程启动时传入的字符串数组

入口：

```java
public static void main(String[] args) {
    System.out.println("count=" + args.length);
}
```

命令：

```bash
javac --release 25 ArgsDemo.java
java ArgsDemo
java ArgsDemo HIGH LOW
```

第一次运行 args.length 为 0；第二次为 2，`args[0]` 是 `"HIGH"`，`args[1]` 是 `"LOW"`。shell 按自己的引号规则先把命令拆成参数，JVM 再把每个参数作为一个 String 元素交给 main。`"north gate"` 带引号通常是一个元素；没有引号会被 shell 拆成两个。

命令行参数不是 Java 源码字面量。输入 `5` 到达程序时仍是 String。若本章示例调用 `Integer.parseInt(args[i])`，只把它当作把已知合法数字文本转成 int 的固定 API；缺参数、非数字、错误提示和退出码会在“控制台输入与合法性校验”章节系统学习。

### 12.1 空输入必须先有明确策略

```java
if (args.length == 0) {
    System.out.println("priorities=EMPTY");
    return;
}
```

这不是为了“避免程序报错”而随便加的 guard，而是业务契约：没有参数时不构造虚假的默认工单。若产品需求要求默认优先级，则输出和文档都必须明确默认来源；不能偷偷把 0 当真实输入。

### 12.2 参数数量与数组长度一致

```java
int[] priorities = new int[args.length];
for (int i = 0; i < args.length; i++) {
    priorities[i] = Integer.parseInt(args[i]);
}
```

两个数组使用同一合法索引区间 `[0, args.length)`。每一轮把一个 String 转为对应 int。只要不在循环中改数组引用，长度不会变化；这使索引证明直接可重放。

## 13. 三类高频越界故障

### 13.1 把 length 当最后索引

```java
int last = values[values.length]; // 错
```

非空时最后索引是 `values.length - 1`；空数组没有最后元素，不能只改成 -1 再访问。修复通常是先明确空策略，再在非空分支中访问 `length - 1`。

### 13.2 空参数直接访问

```java
String first = args[0];
```

无参数启动时 args.length=0，索引 0 不满足 `0 < 0`。修复是先检查数量是否满足需求，而不是捕获异常后继续用一个不存在的值。

### 13.3 行列顺序或每行长度假设错误

```java
String value = shifts[1][1];
```

外层索引 1 合法，但第二行长度只有 1，列索引 1 非法。日志应同时记录 row、outerLength、column、rowLength，才能判断失败发生在哪一层。

## 14. 编译成功、运行开始和结果正确是三种证据

数组索引往往来自变量，编译器不能提前知道运行值。因此：

- `javac` 成功只证明语法、类型和可解析名称满足编译要求；
- 进程开始只证明入口和 classpath 基本可用；
- 退出码 0 只证明这次未以错误结束；
- 固定输出或断言匹配才支持“这个输入得到了预期业务结果”；
- 空、单项、多项和故障输入都覆盖，才能支持边界声明。

一个程序可能遍历少一个元素但仍退出 0；也可能对三项成功、对空数组越界。不要用单次绿灯替代输入矩阵。

## 15. 读异常栈：先找第一条自己的源码位置

故意执行 `values[values.length]`，典型 stderr 包含：

```text
Exception in thread "main" java.lang.ArrayIndexOutOfBoundsException:
Index 3 out of bounds for length 3
    at LastIndexFailure.main(LastIndexFailure.java:4)
```

稳定事实是异常类型、非法索引、数组长度和你的源码行。JDK 补充措辞可能调整，因此验证脚本只核对必要片段，不把整段堆栈当永久快照。

诊断顺序：

1. 确认失败阶段是运行而不是编译；
2. 找第一条属于项目源码的栈帧；
3. 抄下 index 与 length；
4. 回到访问前推导合法区间；
5. 找 index 从何处产生；
6. 最小修复边界或输入契约；
7. 复跑原故障、空、单项、多项。

只在报错行加 `try/catch` 并不能证明业务正确；异常处理属于后续主题，本章先修正越界来源。

## 16. 可观察日志：记录边界，不泄露数据

调试遍历可以暂时输出：

```text
event=array-read index=2 length=3
event=search-complete target=4 foundIndex=1 inspected=2
event=matrix-read row=1 rows=2 column=0 rowLength=1
```

生产日志不要直接打印所有命令行参数，因为参数可能含路径、令牌或个人信息。优先记录参数数量、校验结果、索引和脱敏业务标识。数组很大时逐元素日志会造成磁盘与性能问题；用小型可重复输入做教学轨迹，真实服务只保留必要汇总。

## 17. 测试数组边界的最小矩阵

任何“遍历全部元素”的逻辑至少检查：

| 场景 | 输入 | 应证明什么 |
| --- | --- | --- |
| 空 | `{}` | 零轮；不访问首尾；空策略明确 |
| 单项 | `{4}` | 索引 0 恰好一次；首尾是同一项 |
| 多项 | `{3,5,2}` | 0..length-1 全覆盖且顺序正确 |
| 重复目标 | `{4,2,4}` | 查找定义是第一个、最后一个还是全部 |
| 全负值 | `{-3,-1,-5}` | max 不依赖错误的 0 初值 |
| 故障 | `index=length` | 稳定非零、异常类型和源码位置可见 |

二维数组再增加外层空、空行、不等长行和行列颠倒。命令行参数增加 0 个、1 个、多个。测试不是“造很多随机数字”，而是让每个边界声明都有一条能推翻它的输入。

## 18. Java `assert` 在本章的用途与边界

配套实验使用 `java -ea` 打开断言：

```java
assert priorities.length == 3;
assert max == 5;
```

断言适合零依赖教学 oracle，能在条件为 false 时非零失败。默认运行 Java 时断言可能关闭，所以脚本必须显式传 `-ea`。生产业务校验不能依赖 assert；JUnit 在后续 Maven/JUnit 章节学习。

验证脚本还会核对精确输出行数、预期失败的非零退出和关键 stderr。脚本自身退出 0 只说明脚本声明的检查通过，要同时阅读它到底检查了哪些输入。

## 19. FactoryCare 场景：工单优先级批次

假设进程接收若干已经由调用方保证为整数的优先级文本：

```bash
java PriorityBatch 3 5 2
```

程序契约：

1. args.length=0 时输出 `count=0 max=NONE urgent=0`；
2. 否则构造同长度 int 数组；
3. 从索引 0 到 length-1 转换并累计；
4. priority>=4 计为紧急；
5. 最大值从第一个真实元素初始化；
6. 输出只包含汇总，不泄露整个参数列表。

这个示例只证明数组和索引规则。它还不是可上线入口：非数字、超范围、权限、审计、错误退出码、金额溢出都尚未实现。教程会在后续章节逐层补齐，不应让 AI 一次生成所有生产功能而越过学习边界。

## 20. 二维 FactoryCare 场景：班次人员表

```java
String[][] shiftMembers = {
    {"A01", "A02"},
    {"B01"},
    {}
};
```

外层索引是班次编号，内层索引是该班次内的位置。第三个班次存在但无人，`shiftMembers[2].length == 0`。汇总人数需要双层循环；访问一个坐标前同时验证班次和该行位置。不要把空行误解成“不存在班次”。

需求若改成“每个员工对应多个班次”，数据维度的含义改变，不能只交换 `[row][column]`。先重写坐标定义、输入例子和输出 oracle，再改代码。

## 21. 性能与资源安全的基础判断

遍历和线性查找最多读取 length 个元素，工作量随数组长度线性增长。数组一次分配固定连续索引空间；请求创建极大数组可能耗尽堆内存。当前练习只使用固定小数组，不接受不可信长度直接分配。

```java
int size = Integer.parseInt(args[0]);
int[] values = new int[size];
```

这段并非安全的生产代码：负数会失败，巨大正数可能造成资源耗尽，文本也可能不是数字。后续输入验证章节会建立范围契约。本章应能指出风险，但不要提前用复杂异常框架掩盖它。

## 22. 实验闭环

进入[0、1、N、别名与二维边界实验](../../../labs/encyclopedia/ch.java.arrays-command-args/README.md)。

### 22.1 预测

运行前手写：空、单项、多项的 length 与合法索引；`alias[0]` 修改后原变量观察值；最大值和 foundIndex；二维每行 length；无参数和三个参数的输出。再预测三个故障分别在哪一层失败。

### 22.2 构建与运行

```bash
cd labs/encyclopedia/ch.java.arrays-command-args
./verify.sh
```

有效证据包括正常输出、`assertions=14 passed`、三个预期故障的非零状态和 `LAB PASS`。不能删除故障探针来制造全绿。

### 22.3 需求变化

选择一个小改动：把多项数组加一个优先级 4；把查找目标从 4 改为 2；给第三班次增加一人；把命令行参数从三项改为一项。先更新手算 oracle，再改代码并复跑。

### 22.4 故障—修复—复跑

临时把 `< length` 改成 `<= length`，确认异常 index 与 length；恢复后复跑空、单项、多项。或交换一个二维坐标，先判断外层还是内层越界，再看 stderr。每次只注入一种故障。

## 23. 公开练习与无 AI 训练

进入[工单优先级批次](../../../exercises/encyclopedia/ch.java.arrays-command-args/README.md)，关闭 AI，限时 30 分钟。起始代码能编译并退出，但包含三个逻辑 TODO；公开 verifier 会明确显示 `mode=starter-pending`，修复后同一脚本显示 `mode=solved`。

提交：

- 修复前预测与实际四行；
- 每一处 TODO 对应的边界规则；
- 空数组、单项、多项的输出；
- 一次 `index=length` 预期失败日志；
- 需求改成“找最后一个 4”后的新规则；
- 60–120 秒复述索引区间、别名和 args 空边界。

无 AI 阶段不能打开私有答案。完成第一次尝试后，可让 AI 只审查“是否覆盖所有合法索引”和“是否把别名误当复制”，但结论必须用脚本或手算验证。

## 24. 常见误解与纠正

### 24.1 “length 是最后一个索引”

错误。length 是数量；非空时最后索引是 length-1。用空、单项和三项各画一次格子即可纠正。

### 24.2 “数组赋值会复制所有元素”

错误。数组变量赋值复制引用值，产生别名。要独立数据必须创建新数组并复制元素。

### 24.3 “增强 for 能直接改数组里的 int”

错误。循环变量得到元素值的副本；给循环变量赋值不回写。要改指定元素，使用索引。

### 24.4 “二维数组每行一定一样长”

错误。Java 是数组的数组，每行有自己的 length。任何内层访问都使用当前行边界。

### 24.5 “无命令行参数时 args 是 null”

错误。正常 JVM 入口提供长度为 0 的 String 数组。`args[0]` 越界，`args.length` 可安全读取。

### 24.6 “异常栈很长，所以问题很复杂”

不一定。先看异常类型和第一条自己的源码位置，再比对 index 与 length。不要从堆栈最后一行倒着猜。

## 25. AI 协作审查清单

1. 数组元素类型和业务单位是什么？
2. length 从哪里来，是否受不可信输入控制？
3. 每次访问前能否证明 `0 <= index < length`？
4. 空、单项、多项各是什么行为？
5. max 是否从真实元素初始化？空数组策略是什么？
6. 查找要求第一个、最后一个还是全部匹配？
7. 数组赋值是有意共享还是遗漏复制？
8. 二维每行是否可能为空或不等长？
9. args 为 0 个、1 个、多个时是否都有 oracle？
10. 日志是否泄露完整参数或敏感元素？
11. 失败验证是否确认非零状态和源码位置？
12. AI 是否偷偷引入 List、Stream、泛型或复杂异常处理，越过本章边界？

让 AI 修改需求时先要求它列出索引区间和受影响 oracle。例如：“把查找从第一个 4 改为最后一个 4，保持空数组返回 -1；先给三组输入的新 foundIndex，再做最小修改。”

## 26. 120 秒复述模板

> 数组保存固定长度、同一元素类型的一组值。length 是元素数量，合法索引满足 0<=index<length，所以非空数组最后索引是 length-1，空数组没有合法索引。标准遍历从 0 开始并使用 `< length`；空数组自然执行零轮。数组变量保存引用值，赋值给另一个变量会产生指向同一数组的别名，修改元素双方都可见；独立副本要新建数组并逐项复制。二维数组是数组的数组，外层与每一行分别有边界。main 的 String[] args 是命令行参数数组，无参数时 length 为 0。越界通常编译成功、运行时抛出 ArrayIndexOutOfBoundsException，诊断先看 index、length 与第一条项目源码行。正确性必须覆盖空、单项、多项和预期故障，而不是只看退出码 0。

反例：长度 3 的数组访问索引 3。因为合法区间是 `[0,3)`，索引 3 等于上界，运行时失败。

## 27. 自测题

1. `new int[4]` 的 length、合法索引和默认元素分别是什么？
2. 空数组能否读取 length？能否读取索引 0？
3. 为什么标准遍历写 `i < values.length` 而不是 `<=`？
4. 单项数组的第一个与最后一个索引分别是多少？
5. 如何在非空 int 数组中正确初始化最大值？
6. 全负数数组把 max 初始化为 0 会得到什么错误？
7. 找不到目标时为什么常用 -1？
8. 增强 for 给循环变量赋 0，为什么数组不变？
9. `int[] b = a` 后修改 b[0]，a[0] 为什么变化？
10. 怎样创建真正独立的元素副本？
11. 二维数组 `matrix.length` 与 `matrix[row].length` 各表示什么？
12. 为什么第一行有列 2 不代表第二行也有？
13. 无参数启动时 args 是 null 还是空数组？
14. shell 中带空格参数为什么通常需要引号？
15. 编译成功为何不能证明索引合法？
16. `ArrayIndexOutOfBoundsException` 首先提取哪三类证据？
17. 查找第一个匹配与最后一个匹配的 break 策略有何不同？
18. 大数组长度来自不可信输入会有什么资源风险？

每题至少给一个具体数组或坐标。只背“数组下标从 0 开始”不足以证明你能诊断边界。

## 28. 间隔复习安排

| 时间 | 任务 | 通过证据 |
| --- | --- | --- |
| 当天 | 观察台、实验、公开练习 | 正常输出、14 个断言、3 个预期失败 |
| 第 1 天 | 不看书画空、单项、三项索引 | length 与合法区间全对 |
| 第 3 天 | 手写遍历、最大值、首次查找 | 空边界和哨兵可解释 |
| 第 7 天 | 注入 length、空 args、行列故障 | 能从 stderr 找第一处项目行 |
| 第 14 天 | 审查一段 AI 数组代码 | 找出别名、边界和资源风险 |
| 第 30 天 | 在 FactoryCare 小功能迁移 | 输入矩阵与 oracle 仍完整 |

## 29. 速查表

### 29.1 常用形式

```text
声明                int[] values;
创建                values = new int[3];
初始化              int[] values = {3, 5, 2};
长度                values.length
读取/写入           values[index]
合法索引            0 <= index && index < values.length
完整索引遍历        for (int i=0; i<values.length; i++)
只读值遍历          for (int value : values)
二维外层长度        matrix.length
当前行长度          matrix[row].length
命令行参数数量      args.length
未找到索引哨兵      -1
```

### 29.2 现象到首查位置

| 现象 | 首查 |
| --- | --- |
| 最后一轮崩溃 | 是否使用 `<= length` |
| 第一项没处理 | 循环是否从 1 开始 |
| 无参数才崩溃 | 是否在检查 length 前读 args[0] |
| 改副本却原数组变化 | 是否只是复制了引用形成别名 |
| 全负数组 max 为 0 | max 是否用 0 错误初始化 |
| 第二行越界、第一行正常 | 是否假定每行等长 |
| 查找返回错误重复项 | 需求与 break 位置是否一致 |
| 大输入内存异常 | 是否按不可信长度直接分配 |

## 30. 术语表

| 术语 | 本章定义 |
| --- | --- |
| array | 固定长度、元素类型一致、按整数索引访问的容器 |
| element | 数组某个索引保存的值 |
| index | 元素位置，合法范围从 0 到 length-1 |
| length | 数组元素数量，创建后不改变 |
| empty array | 长度为 0 的真实数组，没有合法索引 |
| traversal | 按规则访问数组元素的过程 |
| linear search | 从一端逐项检查目标的查找方式 |
| alias | 多个变量引用同一个数组的关系 |
| copy | 创建另一个数组并复制元素，后续修改彼此独立 |
| two-dimensional array | 元素仍是数组的外层数组，每行有独立长度 |
| command-line argument | 启动进程时由 shell 传给 main 的 String 元素 |
| bounds check | JVM 在数组访问时验证索引是否合法 |
| `ArrayIndexOutOfBoundsException` | 数组索引小于 0 或大于等于 length 时的运行时异常 |
| oracle | 对固定输入的预期输出、断言或预期失败 |

## 31. 本章明确不教什么

本章不教授 `ArrayList`、`List`、Set、Map、泛型、迭代器、Stream、排序、二分查找、可变集合、协变深层规则、反射数组、并发修改、序列化或数据库数组。它们不是“数组语法的顺手补充”，而需要独立契约。

也不完整教授 `Integer.parseInt` 失败处理、Scanner、EOF、退出码、异常设计、对象字段或方法抽取。示例只对固定合法数字参数做转换；下一章先学习方法，之后的输入章节再建立可靠进程边界。

## 32. JDK 25 官方来源

以下官方资料复核日期为 **2026-07-16**：

- [Java Language Specification 25, §10 Arrays](https://docs.oracle.com/javase/specs/jls/se25/html/jls-10.html)：数组类型、变量、创建、初始化、成员、访问与运行时边界检查。
- [JLS 25, §10.4 Array Access](https://docs.oracle.com/javase/specs/jls/se25/html/jls-10.html#jls-10.4)：数组访问表达式、索引检查与越界异常。
- [JLS 25, §10.7 Array Members](https://docs.oracle.com/javase/specs/jls/se25/html/jls-10.html#jls-10.7)：数组的 public final `length` 字段。
- [JLS 25, §14.14.2 The enhanced `for` statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.14.2)：增强 for 在数组上的翻译与执行边界。
- [JLS 25, §15.10 Array Creation and Access Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.10)：数组创建、初始化与索引表达式的求值。
- [JLS 25, §12.1.4 Invoke `Test.main`](https://docs.oracle.com/javase/specs/jls/se25/html/jls-12.html#jls-12.1.4)：Java 虚拟机启动入口时把命令行参数传给 `main` 的规则。
- [Java SE 25 API, `ArrayIndexOutOfBoundsException`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/ArrayIndexOutOfBoundsException.html)：非法数组索引的 API 契约。

官方规范给出语言边界，配套实验给出当前程序的可重复证据。博客或 AI 若声称“length 是最后索引”“数组赋值会复制元素”或“无参数 args 为 null”，应以 JDK 25 规范与本章实验为准。
