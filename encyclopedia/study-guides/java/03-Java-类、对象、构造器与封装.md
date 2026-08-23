# Java：类、对象、构造器与封装

## 1. 为什么程序需要对象

前面写过的方法通常接收几个参数，算出一个结果：

```java
long totalCents = calculateTotalCents(unitPriceCents, quantity);
```

这种写法适合一次计算。但真实业务中的“设备”或“工单”往往不只有一个值：它有编号、名称和状态，也会经历登记、开始维修、完成维修等变化。如果这些数据散落在许多变量中，程序很难保证它们始终属于同一台设备，也很难把状态规则放在一个可靠的位置。

Java 的类和对象就是用来组织这类数据与行为的。

- **类（class）**规定某一类对象有哪些数据、可以做哪些事情；
- **对象（object）**是程序运行时真正创建出来的一份具体数据；
- **实例（instance）**也是对象，强调它是某个类的具体实例。

可以把类想成“设备登记表的结构说明”，把对象想成“某一台具体设备的登记记录”。结构说明只有一份，也可以按照它创建很多条彼此独立的记录。

```java
class Device {
    String code;
    String status;
}
```

这段代码只是声明了 `Device` 这种类型，还没有创建任何具体设备。真正创建对象要执行 `new`：

```java
Device pump = new Device();
Device sensor = new Device();
```

这里执行了两次 `new Device()`，因此创建了两个对象。它们都具有 `code` 和 `status`，但各自保存自己的值。

```text
pump   ──> Device 对象 A
sensor ──> Device 对象 B
```

类不只是“复制对象用的模板”。它也是一种类型：编译器会根据类的声明检查字段名、方法名、参数和返回值。访问一个根本不存在的成员时，通常会在编译阶段失败。

这一节必须掌握：类是定义，对象是运行时创建出来的具体实例；数有多少个对象时，要看实际执行了多少次 `new`，不能只数变量名。

## 2. 字段：保存每个对象自己的状态

声明在类里面、方法外面的变量叫作**字段（field）**：

```java
class Device {
    String code;
    String status;
    int repairCount;
}
```

每个 `Device` 对象都有自己的一组字段。点号左边说明要找哪个对象，点号右边说明要访问该对象的哪一项数据：

```java
pump.code = "PUMP-01";
pump.status = "IDLE";

sensor.code = "SENSOR-07";
sensor.status = "IDLE";
```

`pump.status` 和 `sensor.status` 虽然字段名相同，但它们位于两个不同对象中。修改其中一个，不会自动修改另一个。

### 2.1 字段和局部变量不是一回事

字段属于对象，可以在多次方法调用之间保留状态。局部变量属于某一次方法调用，只在对应的方法或代码块中使用：

```java
class Device {
    int repairCount; // 字段

    void completeRepair() {
        int increase = 1; // 局部变量
        repairCount = repairCount + increase;
    }
}
```

二者还有一个重要差别：

- 新对象的字段会先得到语言默认值，例如引用字段是 `null`，`int` 是 `0`，`boolean` 是 `false`；
- 局部变量必须先明确赋值，才能读取。

语言默认值只代表 Java 能给出一个技术上的初值，不代表这个值符合业务。例如设备编码为 `null` 通常不是一台合法设备。后面会用构造器关闭这种“对象已经存在，但信息还没填完整”的窗口。

### 2.2 一个类应该保存彼此相关的状态

不要为了“使用面向对象”就把任何变量都塞进同一个类。可以先问：

1. 这些字段是否共同描述同一个业务概念？
2. 这些字段是否需要一起满足某些规则？
3. 修改规则时，是否有一个清楚的位置可以维护？

设备编码、名称和设备状态可以属于 `Device`。数据库连接、当前登录用户、短信发送器和页面颜色通常不应该都成为 `Device` 的字段，因为它们属于不同职责。

## 3. 实例方法：让对象自己执行与状态有关的行为

没有 `static` 的普通成员方法叫作**实例方法（instance method）**：

```java
class Device {
    String status;

    void startRepair() {
        status = "IN_REPAIR";
    }
}
```

调用时必须先有一个具体对象：

```java
pump.startRepair();
```

`pump` 是这次调用的**接收者（receiver）**。程序会找到 `pump` 指向的对象，然后以这个对象作为当前对象执行方法。因此这次调用修改的是泵，而不是所有 `Device`。

同一份方法代码可以服务很多对象：

```java
pump.startRepair();
sensor.startRepair();
```

第一次调用时，当前对象是 `pump` 指向的对象；第二次调用时，当前对象是 `sensor` 指向的对象。

### 3.1 this 表示“这次调用的当前对象”

实例方法中的 `this` 指向当前接收者：

```java
void startRepair() {
    this.status = "IN_REPAIR";
}
```

调用 `pump.startRepair()` 时，`this` 是泵对象；调用 `sensor.startRepair()` 时，`this` 是传感器对象。`this` 不是当前类，也不是一个全局固定对象。

字段和参数同名时，`this` 能明确区分二者：

```java
void rename(String code) {
    this.code = code;
}
```

- 左边的 `this.code` 是对象字段；
- 右边的 `code` 是这次调用传入的参数。

下面的写法可以编译，却不会修改对象：

```java
void rename(String code) {
    code = code;
}
```

两边都指向参数，相当于把参数自己的值再放回参数。方法正常结束，但对象字段仍然没变。这叫作**名称遮蔽（shadowing）**导致的逻辑错误。

### 3.2 用业务行为代替散落的字段修改

外部直接写：

```java
device.status = "IN_REPAIR";
```

只表达了“改一段数据”，没有说明什么时候允许改。对象提供行为：

```java
device.startRepair();
```

则可以把检查和修改放在一起：

```java
void startRepair() {
    if (!"REGISTERED".equals(status)) {
        throw new IllegalStateException("device cannot start repair");
    }
    status = "IN_REPAIR";
}
```

方法名表达业务意图，规则也有固定归属。以后允许的前置状态改变时，只需修改拥有规则的位置，不必在每个页面、脚本和调用者中重复查找。

这一节必须掌握：实例方法总是针对某个接收者工作，`this` 指向这个接收者；与对象状态有关的业务变化，优先放进表达意图的方法中。

## 4. 引用：变量和对象不是同一个东西

普通对象变量保存的是**引用值**，程序通过引用找到对象：

```java
Device pump = new Device();
```

这里有三个不同动作：

1. `new Device()` 创建对象；
2. 创建表达式得到一个指向该对象的引用；
3. 这个引用值保存到变量 `pump` 中。

不要把引用简单说成可以读取和计算的真实内存地址。源码层只需要知道它能让程序找到对象；JVM 可以用不同方式实现对象存储。

### 4.1 两个变量可以指向同一个对象

```java
Device first = new Device();
Device second = first;
```

第二行没有创建对象，也没有复制对象，只是把 `first` 里的引用值复制给 `second`：

```text
first  ─┐
        ├──> 同一个 Device 对象
second ─┘
```

多个引用指向同一个可变对象，叫作**别名（aliasing）**。通过任意一个别名修改对象，其他别名都能观察到变化：

```java
second.startRepair();
System.out.println(first.status); // 也会看到 IN_REPAIR
```

这不是 Java 偷偷同步了两个对象，而是从头到尾只有一个对象。

### 4.2 变量改指向，不代表旧对象被修改

```java
Device first = new Device();
Device second = first;
second = new Device();
```

最后一行创建了第二个对象，并让变量 `second` 改为指向新对象。`first` 仍然指向原对象，原对象没有被这次变量赋值改写。

分析引用代码时，把动作分成三类会清楚很多：

- `new`：创建新对象；
- `a = b`：改变变量保存的引用；
- `a.status = ...` 或 `a.startRepair()`：改变已有对象的状态。

### 4.3 Java 传对象参数时仍然是按值传递

```java
static void start(Device input) {
    input.startRepair();
}
```

调用 `start(pump)` 时，Java 会把 `pump` 中保存的引用值复制给参数 `input`。两者暂时指向同一个对象，所以方法内修改对象状态，调用者可以看到。

如果方法内只让参数改指向：

```java
static void replace(Device input) {
    input = new Device();
}
```

改变的只是局部参数 `input`，调用者变量 `pump` 不会自动改指向。Java 始终按值传递；对象场景复制的那个“值”恰好是引用。

### 4.4 null 表示“当前没有对象”

```java
Device device = null;
```

`null` 不是空对象，也不是字段都为空的 `Device`。它表示变量当前没有指向任何对象。通过它访问字段或调用实例方法时，运行阶段会出现 `NullPointerException`：

```java
device.startRepair();
```

不要看到空引用异常就在所有位置随意加判空。先明确业务契约：这个位置允许没有设备吗？

- 如果允许缺失，应有明确的缺失分支；
- 如果不允许，应在更早的输入或创建边界拒绝；
- 如果对象存在但字段无效，单纯检查非 `null` 也解决不了。

`null`、空字符串 `""`、只有空格的字符串和一个真实对象，是不同状态。

这一节必须掌握：变量保存引用，对象有自己的身份和状态；引用赋值不会自动复制对象；`null` 表示没有对象。

## 5. new 和构造器：创建对象时一次给齐必需信息

先创建空对象，再逐项写字段会留下一个危险窗口：

```java
Device device = new Device();
device.code = "PUMP-01";
device.name = "北区循环泵";
device.status = "REGISTERED";
```

第一行执行后，对象已经存在，但编码、名称和状态可能都还无效。如果它在补齐字段前被交给其他代码，后续错误很难定位。

**构造器（constructor）**让对象在创建过程中接收必需信息：

```java
class Device {
    String code;
    String name;

    Device(String code, String name) {
        this.code = code;
        this.name = name;
    }
}
```

调用时把数据交给构造器：

```java
Device pump = new Device("PUMP-01", "北区循环泵");
```

### 5.1 怎样认出构造器

构造器有几个明显特征：

- 名字必须与类名一致；
- 没有返回类型，连 `void` 也不能写；
- 参数写在圆括号中；
- 构造器体在 `new` 的创建过程中执行；
- 构造器中的 `this` 是正在创建的对象。

下面不是构造器，而是一个返回 `void` 的普通方法：

```java
void Device(String code) {
    this.code = code;
}
```

只看名字容易误判，一定要检查前面是否写了返回类型。

### 5.2 默认构造器并不是永远存在

如果一个类没有声明任何构造器，编译器在满足规则时会提供一个默认构造器，因此简单类可以写：

```java
new Device();
```

一旦自己声明了任意构造器，编译器就不会额外赠送原来的默认构造器：

```java
class Device {
    Device(String code) {
        this.code = code;
    }
}
```

此时 `new Device()` 会编译失败，除非你明确再写一个无参构造器。

不要为了消除红线就随手补无参构造器。如果设备编码是必需信息，无参创建本来就无法生成合法设备。正确方向通常是让调用者提供必需值。

### 5.3 构造器不是“以后随时重新初始化”的方法

构造器只参与对象创建，创建完成后不能写：

```java
device.Device("NEW-CODE");
```

如果对象以后允许改名，应提供 `rename(...)` 之类的业务行为；如果不允许，就不应该提供修改入口。创建和后续状态变化是两个不同阶段。

## 6. 初始化顺序：字段怎样得到第一个值

字段可以在声明处设置初值：

```java
class Device {
    String status = "REGISTERED";
    int repairCount = 0;
    String code;

    Device(String code) {
        this.code = code;
    }
}
```

在暂时不展开继承的情况下，可以用下面的简化顺序理解一次创建：

1. 先计算 `new Device(...)` 中的参数；
2. 创建对象，字段先具有语言默认值；
3. 按源码顺序执行字段初始化器和实例初始化块；
4. 执行最终负责初始化的构造器体；
5. 构造成功后，`new` 才把可用引用交给调用点。

字段初始化器适合表达所有创建入口都相同的业务初值，例如新设备默认是 `REGISTERED`。它不能替代必需输入的验证。

### 6.1 构造器也可以重载

一个类可以有参数列表不同的多个构造器：

```java
class Device {
    String code;
    String name;
    String status;

    Device(String code, String name) {
        this(code, name, "REGISTERED");
    }

    Device(String code, String name, String status) {
        this.code = code;
        this.name = name;
        this.status = status;
    }
}
```

`this(...)` 表示把当前创建过程交给本类的另一个构造器。这样可以让多个入口共用同一套初始化规则，避免复制三份校验代码。

初学和普通业务代码中，把 `this(...)` 放在构造器最前面最清楚，也最容易兼容不同项目语言级别。构造器之间不能形成互相调用的死循环，必须有一个入口真正完成字段初始化。

重载不是越多越好。更稳妥的做法是保留一个维护完整规则的主入口，其他入口只补明确默认值，然后委托给主入口。

## 7. 对象不变量：合法对象始终要满足的规则

有些规则不应该只在某个页面或某次保存时碰巧检查。例如：

- 设备编码不能为空；
- 设备名称不能只有空格；
- 维修次数不能是负数；
- 创建时的状态必须属于允许范围。

只要对象被当作合法对象使用，这些规则就应该成立。这样的规则叫作**对象不变量（invariant）**。

构造器是建立初始不变量的重要边界：

```java
class Device {
    private String code;
    private String name;
    private String status;

    Device(String code, String name) {
        String normalizedCode = requireText(code, "code");
        String normalizedName = requireText(name, "name");

        this.code = normalizedCode;
        this.name = normalizedName;
        this.status = "REGISTERED";
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must have text");
        }
        return value.strip();
    }
}
```

这里先验证和整理参数，全部成功后再写字段。创建过程只有两种结果：

- 输入合法，调用者得到一个满足规则的对象；
- 输入不合法，创建失败，调用者得不到一个可用的半成品对象。

### 7.1 为什么通常先验证，再赋给字段

简单类中即使先赋字段、后抛异常，调用者通常也拿不到最终对象；所以不能把“先赋值”一律说成对象必然泄漏。先验证再集中赋值仍然更稳妥，因为：

- 方法不会在验证前看到无效字段；
- 后续维护者更容易看出字段何时开始可信；
- 多字段失败时更容易定位；
- 可以避免构造过程中把 `this` 注册到列表、回调或线程后，让外部观察到半成品。

构造期间不要把 `this` 传出当前对象边界，是一个值得养成的习惯。

### 7.2 不变量不仅由构造器维护

构造器只负责创建时的合法状态。对象后续允许变化时，每个公开行为也必须保持不变量：

```java
public void startRepair() {
    if (!"REGISTERED".equals(status)) {
        throw new IllegalStateException("invalid transition");
    }
    status = "IN_REPAIR";
}
```

如果外部还能绕过方法直接改字段，不变量依然守不住。这正是封装要解决的问题。

这一节必须掌握：不变量是合法对象始终满足的规则；构造器负责建立合法起点，后续行为负责在变化时继续维护它。

## 8. 封装：让状态和规则待在同一个边界里

**封装（encapsulation）**不是简单地“把字段改成 private”。它真正要做的是：让拥有状态的一方也拥有改变状态的规则，外部只能使用经过设计的入口。

```java
public class Device {
    private final String code;
    private String status;

    public Device(String code) {
        this.code = requireText(code, "code");
        this.status = "REGISTERED";
    }

    public String code() {
        return code;
    }

    public String status() {
        return status;
    }

    public void startRepair() {
        if (!"REGISTERED".equals(status)) {
            throw new IllegalStateException("invalid transition");
        }
        status = "IN_REPAIR";
    }
}
```

外部可以读取必要结果，也可以请求开始维修，但不能直接把状态写成任意文本。将来内部把 `String status` 改成枚举，只要公开行为保持一致，调用者通常不需要知道字段怎样保存。

### 8.1 private 主要建立代码边界，不是安全保险箱

`private` 会阻止普通外部源码直接访问字段，这是很有价值的编译期约束。但它不等于：

- 数据已经加密；
- 当前用户已经通过授权；
- 数据库行已经完成租户隔离；
- 日志不会泄露敏感内容；
- 反射、调试器或进程内代码永远无法观察内部。

封装解决对象设计和可维护性问题；身份认证、权限、数据库约束和加密属于其他安全边界。

### 8.2 getter 和 setter 不会自动形成封装

把字段设为 `private`，再为每个字段生成通用 setter：

```java
public void setStatus(String status) {
    this.status = status;
}
```

外部仍然可以写入 `null`、空白或任意未知状态。它只是把字段赋值包进一个方法，规则仍然泄漏。

领域对象更适合用意图明确的行为：

```java
assignTo(technicianId);
startRepair();
completeRepair();
```

getter 也应该只暴露调用者真正需要的结果。不是所有 setter 都错误，例如简单配置载体可能确实需要可写属性；但每一个公开修改入口都应该能回答“谁为什么有权这样改变状态”。

### 8.3 private 字段照样可以测试行为

验证封装不需要读取私有字段。可以通过公开结果观察：

- 创建后状态是什么；
- 调用 `startRepair()` 后状态是什么；
- 非法顺序是否被拒绝；
- 外部是否不存在任意写状态的入口。

如果为了让测试方便就把字段改成 `public`，测试会破坏它本来应该验证的边界。

这一节必须掌握：封装的重点是缩小公共入口，并让公开方法维护对象规则；“字段 private + 全套 getter/setter”不一定是真正封装。

## 9. 包和访问修饰符：决定哪些代码能看见成员

Java 使用访问修饰符控制源码层面的可见范围。

| 写法 | 同一个类 | 同一个包的其他类 | 不同包的普通类 | 常见用途 |
| --- | --- | --- | --- | --- |
| `private` | 可以 | 不可以 | 不可以 | 对象内部实现 |
| 不写修饰符 | 可以 | 可以 | 不可以 | 包内协作 |
| `protected` | 可以 | 可以 | 还要结合继承规则 | 继承扩展点 |
| `public` | 可以 | 可以 | 可以 | 对外承诺 |

不写访问修饰符通常叫作 **package-private**。Java 没有 `package-private` 这个关键字，它就是“什么都不写”。

`protected` 的跨包规则必须和继承、接收者类型一起理解。现在只需要知道它不是“稍微小一点的 public”；不要为了以后可能继承就提前把字段设成 `protected`。

### 9.1 package 是类型完整名字的一部分

```java
package com.factorycare.device.domain;

public class Device {
}
```

这个类型的完整类名是：

```text
com.factorycare.device.domain.Device
```

常见源码目录会与包名逐段对应：

```text
src/main/java/
└── com/
    └── factorycare/
        └── device/
            └── domain/
                └── Device.java
```

目录是构建工具的组织约定，`package` 声明才是类型名字的一部分。初学和常规项目中让二者严格对应，能避免大量“文件明明存在，类却找不到”的问题。

顶层类通常只能是 `public` 或 package-private。一个 `public` 顶层类通常放在与类同名的 `.java` 文件中。

### 9.2 import 只帮你少写完整名字

包外代码可以导入公开类型：

```java
package com.factorycare.device.app;

import com.factorycare.device.domain.Device;

public class Main {
    Device current;
}
```

`import` 的作用是让源码可以写简单名 `Device`。它不会：

- 下载依赖；
- 执行类；
- 复制类；
- 把 `private` 变成 `public`；
- 让 package-private 类型跨包可见；
- 自动把遗漏的源码加入编译。

不写 `import` 时也可以直接使用完整类名：

```java
com.factorycare.device.domain.Device current;
```

`java.lang` 中的常用类型会自动导入，所以 `String` 不需要显式 import。星号导入也不会递归导入子包。

### 9.3 包名相似，不代表拥有包内权限

下面是两个不同的包：

```text
com.factorycare.device
com.factorycare.device.internal
```

Java 不把后者当作前者真正的“子权限域”。`internal` 只是名字；如果其中的类声明为 `public`，其他包仍可能访问。真正的边界来自访问修饰符，以及以后会学习的模块系统。

这一节必须掌握：`package` 参与组成完整类名；`import` 只负责名字解析，不授予访问权限；`public` 是对外承诺，应该尽量小而清楚。

## 10. static：属于类，而不是某个对象

实例字段每创建一个对象就有一份。带 `static` 的字段属于类，所有实例共享同一份类级状态：

```java
class Ticket {
    private static int createdCount;
    private final int number;

    Ticket() {
        createdCount++;
        number = createdCount;
    }
}
```

创建两张票后，`number` 分别保存在两个对象中，而 `createdCount` 是它们共同使用的一份数据。

判断一个成员是否应该是 `static`，不要从“调用起来方便”开始，而要先问归属：

- 每个对象都可能不同的数据，通常是实例字段；
- 所有对象真正共享且不会变化的规则，可能是类级常量；
- 只依赖参数、不读取隐藏状态的计算，可能是静态工具方法；
- 针对某个对象维护状态的行为，应该是实例方法；
- 会变化的共享状态，需要额外审查生命周期、测试隔离和并发风险。

### 10.1 静态方法没有 this

```java
static boolean hasText(String value) {
    return value != null && !value.isBlank();
}
```

可以直接通过类名调用静态方法，不需要先创建对象。正因为没有天然接收者，静态方法中没有 `this`，也不能直接读取某一对象的实例字段。

如果规则需要具体设备，有两个清楚选择：

```java
static String labelOf(Device device) {
    return device.code();
}
```

或者把它变成设备自己的实例方法：

```java
String label() {
    return this.code;
}
```

不要为了消除“静态上下文不能访问实例字段”的编译错误，就把设备编码也改成 `static`。那会让所有设备错误地共享一个编码。

### 10.2 合适的 static 用途

类级固定规则可以写成常量：

```java
private static final int MAX_CODE_LENGTH = 40;
```

无状态计算可以写成静态工具方法：

```java
static boolean isValidPriority(int value) {
    return value >= 1 && value <= 5;
}
```

静态方法还可以命名一种创建方式，这叫作**静态工厂（static factory）**：

```java
public static WorkOrder open(String id) {
    return new WorkOrder(id, "CREATED");
}
```

`open` 比一个参数含义不清的构造器更能表达业务动作。静态工厂和构造器各有用途，不需要把所有创建都改成工厂。

### 10.3 共享可变 static 为什么危险

```java
private static int nextSequence = 1;
```

这种字段会成为所有调用者都能间接影响的隐藏输入：

- 前一个测试消耗编号，后一个测试结果改变；
- 单独运行测试通过，整套运行失败；
- 进程重启后数据丢失；
- 多个 JVM 进程各有一份，不能形成全局唯一编号；
- 多线程同时修改还会遇到竞争问题。

因此，普通静态字段不是数据库、配置中心、用户会话或全局业务编号器。当前用户、租户、令牌和请求数据更不能为了方便放进可变静态字段。

如果状态属于一段明确生命周期，可以把它放进一个显式对象：

```java
class WorkOrderIdGenerator {
    private int next;

    WorkOrderIdGenerator(int first) {
        this.next = first;
    }

    String nextId() {
        return "WO-%04d".formatted(next++);
    }
}
```

每个测试或站点可以创建自己的编号器，状态归属和生命周期都看得见。它仍不是生产环境的分布式编号方案，只是展示“共享范围应该由需求决定”。

这一节必须掌握：`static` 表示类级归属，不表示“永远不变”；静态方法没有当前对象；可变静态字段会产生隐藏依赖和状态污染。

## 11. final：限制再次赋值，不会自动冻结对象

`final` 修饰变量时，表示它完成赋值后不能再次放入另一个值：

```java
final int maxRetry = 3;
// maxRetry = 4; // 编译失败
```

对基本类型来说，变量里就是数字或布尔值，因此看起来像“值不能改”。对引用类型，不能改变的是引用绑定：

```java
final int[] hours = {8, 10};

hours[0] = 9;          // 可以：修改同一个数组的元素
// hours = new int[]{9}; // 编译失败：试图让变量指向另一个数组
```

这是理解 `final` 最重要的分界：**final 引用不等于被引用对象不可变**。

### 11.1 final 字段

```java
class Device {
    private final String code;

    Device(String code) {
        this.code = code;
    }
}
```

每个 `Device` 对象都有自己的 `code` 字段；该字段必须在字段初始化器或每条正常完成的构造路径中完成赋值。构造完成后，类内代码也不能再让它指向另一个字符串。

这适合表达设备编码一旦创建便不允许替换。`final` 会让漏赋值或二次赋值在编译阶段暴露，但仍不能替代 `null`、空白和格式校验。

### 11.2 static final 和常量

```java
private static final String DEFAULT_CURRENCY = "CNY";
```

`static` 表示全类共享一份，`final` 表示这个字段不能重新赋值。类级固定值通常采用全大写加下划线的名字。

但下面不是安全的不可变常量：

```java
public static final int[] DEFAULT_HOURS = {8, 10};
```

引用不能换，数组元素仍能被任何调用者修改。不要公开 `static final` 的可变数组、集合或业务对象。

### 11.3 final 类和 final 方法先认识名字

`final class` 表示类不能被继承，`final` 方法表示子类不能重写。它们的完整取舍会在继承章节展开。现在只需要知道：同一个关键字放在变量、字段、方法和类上，限制的对象不同，不能用一句“final 就不能改”概括全部规则。

## 12. 不可变对象：变化时返回一个新对象

如果对象构造完成后，调用者无法通过公开路径观察到它的逻辑状态发生变化，这种对象叫作**不可变对象（immutable object）**。

一个常见不可变值类型会满足这些条件：

1. 字段是 `private`；
2. 构造时验证全部规则；
3. 字段通常是 `final`；
4. 不提供改变状态的 setter 或命令；
5. 计算变化时返回新对象；
6. 不接收或泄露共享的可变内部对象。

例如金额：

```java
public final class Money {
    private final long cents;
    private final String currency;

    public Money(long cents, String currency) {
        if (cents < 0) {
            throw new IllegalArgumentException("cents must not be negative");
        }
        if (currency == null || currency.isBlank()) {
            throw new IllegalArgumentException("currency must have text");
        }
        this.cents = cents;
        this.currency = currency;
    }

    public Money plus(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("currency mismatch");
        }
        return new Money(Math.addExact(cents, other.cents), currency);
    }

    public long cents() {
        return cents;
    }
}
```

`plus` 不修改原来的两个金额，而是返回一个新 `Money`：

```java
Money total = base.plus(fee);
```

调用者必须接住返回值。只写 `base.plus(fee);` 会丢弃新对象，`base` 不会自动变化。这与 `String.toUpperCase()` 返回新字符串的思路相似。

### 12.1 final 字段仍不足以保证不可变

```java
class MaintenanceWindow {
    private final int[] hours;

    MaintenanceWindow(int[] hours) {
        this.hours = hours;
    }
}
```

虽然字段是 `final`，调用者仍然保留原数组引用。构造完成后修改原数组，对象内部也会变化。

解决输入别名需要在边界复制：

```java
this.hours = hours.clone();
```

查询时也不能直接返回内部数组：

```java
public int[] hours() {
    return hours.clone();
}
```

这种在输入和输出边界创建副本的做法叫作**防御性复制（defensive copy）**。

### 12.2 浅复制和深复制

`int[]` 的元素是基本值，复制数组就复制了所有元素。若数组是 `Device[]`，复制数组只会复制其中的引用；新旧数组仍然指向同一批可变设备对象。这叫作浅复制。

深复制需要明确每个元素怎样复制以及业务身份是否允许复制。不能看到引用共享就盲目“深拷贝一切”，因为两处引用同一张工单有时正是业务要求。

### 12.3 不可变不是所有对象的唯一答案

金额、设备编码、时间点等值通常适合不可变。工单有自己的业务身份和生命周期，可能需要由受控方法改变状态。更重要的问题是：

- 这是一个“值”，还是一个会持续存在并变化的实体？
- 哪些变化应该返回新值？
- 哪些变化应该由同一实体维护？
- 谁拥有规则和生命周期？

不可变对象能减少远处修改和并发写入，但 `final` 不是锁，也不能自动让整个服务线程安全。

这一节必须掌握：不可变性是公开可观察行为的整体契约，不是给字段加上 `final` 就完成；可变输入和输出要检查别名与复制边界。

## 13. 怎样判断一段对象代码设计得是否清楚

看到一个陌生类时，可以按下面的顺序阅读：

1. 类名代表什么业务概念？
2. 字段分别保存什么，哪些是实例字段，哪些是静态字段？
3. 构造器要求哪些必需输入，创建后保证哪些规则？
4. 哪些字段能变化，变化入口在哪里？
5. 公开方法是业务行为，还是任意 getter/setter？
6. 是否返回或保存了数组、集合等可变引用？
7. `static` 数据的所有者和生命周期是什么？
8. `final` 限制的是变量重新赋值，还是对象真的不可变？
9. `null` 在每个入口代表什么？
10. 包和访问修饰符是否只暴露真正需要的 API？

### 13.1 常见故障分别属于什么阶段

| 现象 | 失败阶段 | 常见原因 |
| --- | --- | --- |
| 找不到字段或方法 | 编译阶段 | 成员名错误或静态类型不支持 |
| 有参构造器存在后 `new Device()` 失败 | 编译阶段 | 默认构造器不再自动生成 |
| 静态方法直接读取实例字段 | 编译阶段 | 没有具体接收者 |
| 给 final 变量再次赋值 | 编译阶段 | 违反单次赋值约束 |
| 通过 `null` 调用实例方法 | 运行阶段 | 接收者没有对象 |
| 构造器拒绝空编码 | 运行阶段的预期拒绝 | 输入违反创建规则 |
| `code = code` 后字段仍为空 | 逻辑错误 | 参数遮蔽字段，忘写 `this` |
| 两个对象状态意外一起变化 | 逻辑错误 | 两个变量其实是别名，或字段被误写成 static |
| 单测单独通过、整套失败 | 状态污染 | 测试共享可变 static 状态 |
| final 数组内容仍被改动 | 设计错误 | 误把引用稳定当成对象不可变 |

编译成功只证明语法和静态类型满足编译器要求；退出码为 0 只证明没有未处理失败。对象是否满足业务规则，还要观察公开行为的结果和边界。

### 13.2 这一章现在要掌握到什么程度

必须掌握：

- 类、对象、实例、字段和实例方法的关系；
- `new`、引用、别名、`null` 与 `this`；
- 构造器为什么负责合法创建；
- 对象不变量和封装的实际作用；
- `static` 成员与实例成员的归属差别；
- `final` 引用不等于对象不可变；
- 防御性复制的输入边界和输出边界。

见过即可：

- 字段初始化器与构造器委托的完整顺序；
- package-private 顶层辅助类；
- 静态工厂这种命名创建入口；
- 浅不可变、深不可变和类初始化失败这些术语。

需要时查询：

- `protected` 的跨包继承细则；
- JVM 的真实对象布局和垃圾回收时间；
- 编译期常量的二进制兼容细节；
- Java 模块系统、反射访问和框架构造规则；
- 集合的不可变副本和并发安全实现。

读完这篇讲义后，应该形成一条完整主线：类定义一类对象的状态与行为；`new` 通过构造器创建具体对象；引用让代码找到对象；封装让对象自己维护规则；`static` 用于真正属于类的内容；`final` 约束重新赋值，而真正的不可变性还需要整体设计。

