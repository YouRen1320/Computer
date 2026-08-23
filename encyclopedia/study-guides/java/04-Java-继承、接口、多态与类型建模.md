# Java：继承、接口、多态与类型建模

## 1. 这一组工具解决什么问题

类和封装可以把一类对象的状态与规则放在一起。项目继续变大后，又会出现三类问题：

1. 多种类型有一部分共同规则，怎样复用而不复制代码？
2. 调用方只关心“会发送通知”，怎样不绑定邮件或短信的具体实现？
3. 状态、命令、坐标、金额等数据有明确形状，怎样用类型约束它们，而不是到处传字符串？

Java 提供了几组不同工具：

- **继承**表达“子类型也是一种父类型”，并复用父类的一部分实现；
- **组合**让一个对象持有另一个对象，把工作委托给协作者；
- **接口**描述一项能力或契约，不规定调用者必须依赖哪个实现；
- **多态**让同一段调用代码根据实际对象执行不同实现；
- `enum`、`record` 和 `sealed` 用来表达有限状态、数据值和受限类型集合；
- `equals`、`hashCode`、`toString` 规定对象怎样比较、怎样参与哈希集合以及怎样展示。

这些工具不能只按“哪个写起来短”选择。先判断业务关系、变化方向和公开契约，再选择语法。

## 2. 继承：子类建立一种父子类型关系

最小继承写法使用 `extends`：

```java
class Notification {
    void send(String message) {
        System.out.println(message);
    }
}

class EmailNotification extends Notification {
}
```

`EmailNotification` 是 `Notification` 的子类，`Notification` 是它的父类。子类对象可以使用父类允许继承和访问的成员：

```java
EmailNotification email = new EmailNotification();
email.send("repair created");
```

继承不是把父类源码复制到子类文件。运行时仍然是一个子类对象；编译器根据继承关系决定它有哪些可用成员。

### 2.1 “是一个”必须是行为上的关系

判断继承时常用“子类是不是一种父类”作为第一步，但仅仅中文读起来通顺还不够。更重要的是：任何需要父类型的地方，是否都可以安全地换成这个子类型，而不破坏父类型承诺？

例如，如果父类型承诺任何通知都能发送文本，某个子类却在大部分正常输入上抛出“不支持”，它虽然语法上继承成功，行为上却不能可靠替换父类型。

这种“子类型应能替换父类型”的要求叫作**替换性**，也常与里氏替换原则（Liskov Substitution Principle）一起出现。

### 2.2 继承适合稳定的类型层次

继承通常更适合：

- 子类确实属于父类型；
- 父类契约稳定且对所有子类都成立；
- 子类只细化行为，不否定父类核心承诺；
- 共同状态和生命周期确实应该由同一个抽象父类拥有。

仅仅想复用两行工具代码，通常不足以建立继承关系。深层继承还会让规则散落在多层父类中，阅读一个方法时必须来回跳转。

## 3. 方法重写：子类替换父类的实例行为

子类可以用相同方法签名提供自己的实现，这叫作**方法重写（override）**：

```java
class Notification {
    void send(String message) {
        System.out.println("default:" + message);
    }
}

class EmailNotification extends Notification {
    @Override
    void send(String message) {
        System.out.println("email:" + message);
    }
}
```

`@Override` 会让编译器检查这是否真的重写了父类方法。若参数拼错、方法名拼错或父类没有对应方法，编译器会尽早指出问题。因此重写时应该保留它。

### 3.1 重写、重载和静态隐藏不要混淆

- **重写**：父子类中实例方法签名对应，运行时按实际对象选择实现；
- **重载**：同一个名字有不同参数列表，编译器根据调用点的静态类型和参数选择；
- **静态方法隐藏**：父子类同名静态方法按类型解析，不参加普通实例方法那种动态分派。

```java
void send(String text) { }
void send(String text, int retry) { }
```

这两个是重载，不是重写。

### 3.2 子类不能随意改变父类承诺

重写方法通常不能让调用条件比父类更苛刻，也不能把原先保证的结果削弱掉。例如父类允许任意非空消息，子类不能只接受长度小于十的消息，却仍声称自己是可替换实现。

语言会检查一部分规则，例如方法签名、返回类型和可见性；业务替换性仍需要设计者判断。代码能编译不代表父子契约合理。

## 4. super：访问父类的构造或实现

子类重写后仍可以调用父类实现：

```java
class AuditedEmailNotification extends Notification {
    @Override
    void send(String message) {
        System.out.println("audit:start");
        super.send(message);
    }
}
```

`super.send(...)` 明确调用父类版本，不会再次按普通多态规则选择当前子类重写。

### 4.1 构造链

父类负责的字段通常由父类构造器初始化：

```java
class Notification {
    private final String sender;

    Notification(String sender) {
        this.sender = sender;
    }
}

class EmailNotification extends Notification {
    EmailNotification(String sender) {
        super(sender);
    }
}
```

创建子类对象时，父类部分要先完成初始化，然后才轮到子类字段和子类构造器体。若父类没有可用的无参构造器，子类必须明确调用合适的 `super(...)`。

一个重要警告：父类构造器不要调用可能被子类重写的实例方法。那时子类自己的字段可能尚未完成初始化，动态分派却已经进入子类实现，容易观察到半成品状态。

### 4.2 super 调用太多也是设计信号

如果子类每个方法都要先后调用多个 `super` 方法、知道父类大量内部顺序，说明两者耦合可能过深。继承不是越充分利用越好；当变化经常跨越父子层时，应重新考虑组合。

## 5. 组合：把协作者作为字段使用

**组合（composition）**表达“一个对象拥有或使用另一个对象”：

```java
interface NotificationSender {
    void send(String message);
}

class WorkOrderService {
    private final NotificationSender sender;

    WorkOrderService(NotificationSender sender) {
        this.sender = sender;
    }

    void createWorkOrder() {
        // 创建工单的规则
        sender.send("work order created");
    }
}
```

`WorkOrderService` 不是一种 `NotificationSender`，它只是使用一个发送器。因此组合比继承更符合关系。

### 5.1 委托

对象把某项工作交给字段中的协作者，叫作**委托（delegation）**：

```java
sender.send(message);
```

委托不表示必须把协作者的所有方法原样转发。调用者仍应通过当前类有意义的业务入口工作，当前类只在需要时调用协作者。

### 5.2 为什么常说“优先组合”

组合的常见优势是：

- 依赖在字段和构造器中清楚可见；
- 可以在创建对象时选择不同实现；
- 一个类可以同时组合多个不同能力；
- 更换协作者通常不改变当前类的类型身份；
- 测试时可以提供记录调用的简单实现。

“优先组合”不是“禁止继承”。如果关系确实是稳定的子类型关系，继承仍然合理。它只是提醒：不要仅为复用实现就建立紧耦合父子关系。

### 5.3 选择表

| 问题 | 更可能选择继承 | 更可能选择组合 |
| --- | --- | --- |
| 是否真的是一种父类型 | 是 | 否，只是使用某项能力 |
| 是否需要运行时切换协作者 | 不常见 | 常见 |
| 是否要同时使用多个独立能力 | 受单继承限制 | 可以组合多个字段 |
| 父类内部变化是否会影响子类 | 影响较大 | 边界通常更局部 |
| 是否只是为了复用几行代码 | 不充分 | 通常更合适 |

这一组必须掌握：继承表达类型关系，组合表达协作关系；判断依据是契约与变化方向，不是代码长度。

## 6. 接口：只规定调用者需要的能力

接口可以声明一项能力：

```java
public interface NotificationSender {
    void send(String recipient, String message);
}
```

实现类使用 `implements`：

```java
public class EmailSender implements NotificationSender {
    @Override
    public void send(String recipient, String message) {
        System.out.println("email to " + recipient);
    }
}
```

接口不是“还没写完的对象”，它是调用双方同意的一份契约。方法签名只描述类型外形，真正契约还包括：

- 哪些输入合法；
- 成功后保证什么；
- 失败怎样表达；
- 是否有副作用；
- 是否允许重复调用；
- 是否有顺序、时效或安全要求。

两个类都实现了接口，不代表它们自然遵守这些行为规则。编译器只能检查声明的一部分。

### 6.1 一个类可以实现多个接口

Java 类只能直接继承一个类，但可以实现多个接口：

```java
class EmailSender implements NotificationSender, AutoCloseable {
    // ...
}
```

这适合表达彼此独立的能力。不过接口不要变成一个巨大清单。调用者只需要发送通知，就不应该被迫依赖管理模板、统计费用和清理数据库等无关方法。

### 6.2 不要为了形式给每个类都配一个接口

如果一个类只有一个实现、没有明确替换点，也没有独立消费者契约，机械地创建 `Something` 和 `SomethingImpl` 往往只增加跳转。接口的价值来自边界，而不是文件数量。

适合提取接口的信号包括：

- 存在多个真正实现；
- 调用方只需要一小部分能力；
- 外部资源需要在测试中替换；
- 模块边界需要稳定契约；
- 实现变化频繁，而调用行为相对稳定。

## 7. 抽象类：共享类型，也共享一部分实现

抽象类不能直接创建实例，可以同时拥有字段、构造器、已实现方法和抽象方法：

```java
abstract class BaseNotificationSender {
    private final String source;

    BaseNotificationSender(String source) {
        this.source = source;
    }

    abstract void send(String message);

    String source() {
        return source;
    }
}
```

接口和抽象类的主要区别不是“接口没有实现”。现代接口也可以有 `default`、`static` 和私有辅助方法。更实用的判断是：

- 接口偏向声明调用者所需能力，一个类可实现多个；
- 抽象类偏向一组紧密相关子类共享状态、构造过程和部分实现；
- 如果只是想复用工具代码，普通协作者或静态纯函数往往更清楚。

### 7.1 default 方法

接口可以提供默认实现：

```java
interface NotificationSender {
    void send(String message);

    default void sendUrgent(String message) {
        send("URGENT: " + message);
    }
}
```

`default` 主要帮助接口在有限范围内演进或提供基于核心能力的通用行为。若两个接口提供冲突默认方法，实现类必须明确解决。不要把接口逐渐堆成带大量状态假设的“隐形父类”。

这一节见过即可：接口可以有默认方法；完整冲突规则需要时查询。

## 8. 多态：变量看见契约，运行时对象决定实现

接口类型的变量可以保存任意合法实现对象：

```java
NotificationSender sender = new EmailSender();
sender.send("ops@example.com", "repair created");
```

这里要区分两个类型：

- **静态类型**是源码中变量声明的 `NotificationSender`，决定编译阶段能调用哪些成员；
- **运行时类型**是实际对象的 `EmailSender`，决定被重写实例方法最终执行哪个实现。

运行时根据实际对象选择重写方法，叫作**动态分派（dynamic dispatch）**。

### 8.1 向上转型

把具体实现放进接口或父类变量通常叫作向上转型：

```java
NotificationSender sender = new SmsSender();
```

它通常是安全的，因为 `SmsSender` 承诺实现 `NotificationSender`。变量只暴露接口中的能力，调用方不会依赖短信实现特有方法。

### 8.2 调用端怎样保持稳定

```java
class WorkOrderNotifier {
    private final NotificationSender sender;

    WorkOrderNotifier(NotificationSender sender) {
        this.sender = sender;
    }

    void notifyCreated(String recipient) {
        sender.send(recipient, "work order created");
    }
}
```

创建 `WorkOrderNotifier` 时可以传入邮件、短信或测试记录器。业务代码始终只调用接口，不需要写：

```java
if (sender instanceof EmailSender) { ... }
else if (sender instanceof SmsSender) { ... }
```

新增第三种实现时，依赖多态的调用端通常不变；依赖类型分支的调用端则要不断修改。

### 8.3 向下转型有运行风险

```java
EmailSender email = (EmailSender) sender;
```

这叫向下转型。若实际对象不是 `EmailSender`，运行时会抛出 `ClassCastException`。`instanceof` 可以防止这次崩溃，但如果业务代码到处判断具体实现，通常说明接口太弱或调用方泄漏了实现细节。

只有在确实处理不同数据形状、框架边界或兼容代码时，向下转型才可能合理。先考虑能否把所需行为放进契约或使用不同协作者。

### 8.4 null 没有可供分派的对象

接口变量可以为 `null`，但调用实例方法时没有实际对象，仍然会出现 `NullPointerException`。多态解决“有哪个实现”，不解决“有没有对象”。

这一节必须掌握：编译阶段看静态类型，重写的实例方法在运行时按实际对象动态分派；多态的价值是让调用端依赖稳定契约。

## 9. enum：把有限状态变成受控类型

如果状态只允许固定几种，使用任意字符串很容易拼错：

```java
String status = "IN_REPAIR";
status = "IN_REPAER"; // 编译器看不出拼写错误
```

枚举 `enum` 把有限选项声明成类型：

```java
enum WorkOrderStatus {
    CREATED,
    ASSIGNED,
    IN_PROGRESS,
    COMPLETED
}
```

字段只能保存这些枚举常量或 `null`：

```java
private WorkOrderStatus status = WorkOrderStatus.CREATED;
```

### 9.1 enum 常量是对象

枚举不只是数字别名。每个常量是该枚举类型的对象，枚举可以有字段、构造器和方法：

```java
enum Priority {
    LOW(1), HIGH(5);

    private final int level;

    Priority(int level) {
        this.level = level;
    }

    int level() {
        return level;
    }
}
```

`values()` 返回全部常量，`valueOf("HIGH")` 按常量名称解析；输入不匹配时会失败。外部接口是否使用同样编码、是否忽略大小写，应由协议明确，不能随意靠 `toString()` 推断。

### 9.2 不要持久化 ordinal

`ordinal()` 是常量在声明中的位置。以后调整顺序或插入新常量，数字就会变化，因此不要把它当作数据库或网络协议编码。为外部协议定义稳定、明确的编码字段更安全。

### 9.3 enum 与 switch

```java
String label = switch (status) {
    case CREATED -> "待分配";
    case ASSIGNED -> "已分配";
    case IN_PROGRESS -> "维修中";
    case COMPLETED -> "已完成";
};
```

当所有常量都列出时，新增枚举值可能让编译器提醒未覆盖分支。这比写一个吞掉所有变化的 `default` 更容易发现协议变化。

## 10. record：简洁表达一组数据值

只需要保存一组数据并按内容比较时，可以使用 `record`：

```java
record Coordinate(double latitude, double longitude) {
}
```

编译器会生成对应组件字段、访问方法、构造器、`equals`、`hashCode` 和 `toString` 等成员：

```java
Coordinate point = new Coordinate(28.68, 115.89);
System.out.println(point.latitude());
```

record 是一种受限类，不是普通类的文本缩写。它适合透明的数据载体和值对象；有复杂可变生命周期和隐藏表示的实体，普通类通常更合适。

### 10.1 紧凑构造器可以验证组件

```java
record DeviceCode(String value) {
    DeviceCode {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("device code is required");
        }
        value = value.strip().toUpperCase(java.util.Locale.ROOT);
    }
}
```

紧凑构造器中不重复写参数列表，可以在组件字段最终赋值前验证和规范化参数。

### 10.2 record 不保证深不可变

```java
record Window(int[] hours) { }
```

数组仍然可变，自动生成的访问器也会返回同一个数组引用。若要不可变边界，仍然需要在构造和访问时复制。`record` 只减少样板，不替代不变量与引用设计。

### 10.3 自动 toString 不代表适合日志

record 的默认 `toString()` 会展示组件值。若组件含令牌、个人信息或大段文本，直接记录可能泄露数据。日志边界仍需显式设计。

## 11. sealed：明确允许哪些子类型

有时一个接口只允许项目内几种已知实现。`sealed` 可以把允许的子类型写进类型系统：

```java
sealed interface Command permits AssignCommand, CompleteCommand {
}

record AssignCommand(String technicianId) implements Command {
}

record CompleteCommand(String note) implements Command {
}
```

获准子类型必须继续表态为 `final`、`sealed` 或 `non-sealed`，说明这条继承链是否还能扩展。

### 11.1 sealed 和 enum 的区别

- `enum` 适合多个选项共享同一种数据形状，例如工单状态；
- `sealed` 层次适合每种情况拥有不同数据形状，例如分配命令有技术员 ID，完成命令有完成说明。

两者都表达“范围有限”，但建模对象不同。

### 11.2 模式 switch

对不同记录类型可以使用模式匹配：

```java
String describe(Command command) {
    return switch (command) {
        case AssignCommand assign -> "assign:" + assign.technicianId();
        case CompleteCommand complete -> "complete:" + complete.note();
    };
}
```

如果 sealed 层次新增一种获准命令，原来的穷尽 `switch` 可能在编译时提醒需要处理。这里的编译失败是有价值的变更报警器。

`sealed` 只限制类型层次，不表示当前用户有权限执行命令，也不替代输入校验。

这一组必须掌握：`enum` 表示有限常量，`record` 表示透明数据值，`sealed` 表示有限子类型；三者都不会自动解决授权、深不可变和外部协议兼容。

## 12. equals：区分对象身份和业务值相等

所有普通 Java 类最终都继承 `Object`。如果类不重写 `equals`，默认行为基本是在判断是否为同一个对象身份：

```java
DeviceId first = new DeviceId("PUMP-01");
DeviceId second = new DeviceId("PUMP-01");

System.out.println(first == second);      // false
System.out.println(first.equals(second)); // 取决于类是否定义值相等
```

在写 `equals` 前，先定义哪些字段构成相等：

- 值对象通常按全部逻辑值比较；
- 有业务身份的实体通常按稳定标识判断，而不是按当前全部可变字段；
- 多租户系统中的 ID 可能必须连同租户 ID 一起比较。

### 12.1 equals 的基本契约

在相关对象没有发生影响相等性的变化时，`equals` 应满足：

- 自反：`x.equals(x)` 为真；
- 对称：`x.equals(y)` 与 `y.equals(x)` 结果一致；
- 传递：若 `x` 等于 `y`，`y` 等于 `z`，则 `x` 等于 `z`；
- 一致：重复调用结果稳定；
- 与 `null` 比较返回 `false`。

对一个不参与继承的值类，可以写出清楚模板：

```java
@Override
public boolean equals(Object other) {
    if (this == other) return true;
    if (other == null || getClass() != other.getClass()) return false;
    DeviceId that = (DeviceId) other;
    return value.equals(that.value);
}
```

是否用 `getClass()` 还是 `instanceof` 与继承契约有关，不能机械套模板。值类设计为 `final` 能让边界更简单。record 会根据组件自动生成值相等。

## 13. hashCode 和 toString：两个紧邻的对象契约

### 13.1 相等对象必须有相等哈希值

若两个对象 `equals` 为真，它们的 `hashCode` 必须相同：

```java
@Override
public int hashCode() {
    return java.util.Objects.hash(value);
}
```

`equals` 和 `hashCode` 应使用同一组逻辑字段。只重写 `equals` 不重写 `hashCode`，对象放进 `HashSet` 或作为 `HashMap` 键时可能无法正确查找。

反方向不成立：哈希值相同的两个对象不一定相等。哈希码也不是加密摘要，不能用来保护密码或验证文件安全。

参与哈希和相等的字段最好稳定不变。如果对象作为 `HashMap` 键后再改变这些字段，它可能留在原来的桶位置，却按新哈希再也找不到。

### 13.2 toString 用于可读诊断，不是外部协议

`toString()` 适合提供简短、稳定到足以诊断的描述：

```java
@Override
public String toString() {
    return "DeviceId[" + value + "]";
}
```

不要把默认或自定义 `toString()` 当作 JSON、数据库格式或长期网络协议，因为实现可能变化。也不要输出密码、令牌、身份证号、完整用户备注等敏感内容。

`equals`、`hashCode` 和 `toString` 都不应该修改对象状态或执行昂贵外部 I/O。

## 14. 业务值类型：让原始字符串和数字带上含义

`String` 可以同时表示设备编号、工单编号、租户 ID 和币种，但这些值不能互换。把格式、规范化和相等规则包进专门类型，叫作**业务值类型**或**值对象**：

```java
record WorkOrderId(String value) {
    WorkOrderId {
        if (value == null || !value.matches("WO-[0-9]{4,}")) {
            throw new IllegalArgumentException("invalid work order id");
        }
    }
}
```

这样方法参数就不会把任意字符串误当工单编号。

### 14.1 正则适合检查文本形状

正则表达式适合固定格式，例如 `WO-` 后面跟数字。`matches()` 检查整个字符串是否匹配，`find()` 检查是否在某处找到片段，二者不能混用。

Java 字符串和正则各有一层转义，因此匹配普通句点时常看到 `"\\."`。复杂嵌套数据不应该用一个巨大正则硬解析；不可信正则还可能造成极端回溯和资源消耗。

### 14.2 金额不要经过二进制 double

十进制金额常用整数最小单位或 `BigDecimal`：

```java
BigDecimal amount = new BigDecimal("19.99");
```

不要写：

```java
new BigDecimal(19.99);
```

因为 `19.99` 已先变成近似的二进制浮点值。字符串构造或 `BigDecimal.valueOf(...)` 更能保留预期十进制含义。

`BigDecimal.equals` 同时考虑数值和小数位尺度，因此 `1.0` 与 `1.00` 可能不相等；`compareTo` 可以用于数值大小比较。是否保留尺度、在哪里舍入、使用哪种舍入模式，都是业务政策，不能随便调用一次 `setScale`。

### 14.3 时间先分清语义

- `Instant` 表示时间线上的一个瞬间，适合跨系统记录事件时间；
- `LocalDate` 表示没有时区的日历日期；
- `LocalDateTime` 表示本地日期和时间，本身不能唯一定位全球瞬间；
- `ZoneId` 表示带规则的地区时区；
- `ZoneOffset` 是某一时刻的固定偏移；
- `Duration` 表示基于时间的持续量；
- `Period` 表示日历年月日差异。

不要依赖机器默认时区解释业务时间。部署到另一地区后，默认时区可能不同；夏令时还会产生某些本地时间不存在或重复出现的情况。时间语义应在接口和模型中明确。

“当前时间”也是依赖。需要可重复测试时，可通过 `Clock` 或显式时间参数传入，而不是在深层规则里到处直接调用当前时间。

### 14.4 UUID 是标识，不是秘密

`UUID` 可以生成和解析标准格式标识：

```java
UUID id = UUID.randomUUID();
UUID parsed = UUID.fromString(text);
```

UUID 适合降低分布式生成标识的碰撞风险，但它不是认证令牌，也不自动证明调用者有权访问对应资源。外部公开 ID 是否可枚举、是否需要额外权限，仍由安全设计决定。

这一节见过即可：正则、`BigDecimal`、Java 时间类型和 UUID 都是建模工具。真正项目中要先确定业务语义，再选择 API，而不是反过来用某个 API 猜规则。

## 15. 本章概念怎样连成一条线

可以用下面的顺序理解这一整章：

1. 先用类与封装定义单个对象的规则；
2. 真正稳定的“是一种”关系才使用继承；
3. 只是使用一项能力时优先考虑组合；
4. 用接口让调用方依赖能力契约；
5. 运行时由实际对象完成多态分派；
6. 用 `enum` 表示有限状态；
7. 用 `record` 表示透明数据值；
8. 用 `sealed` 表示有限且形状不同的子类型；
9. 值对象必须明确 `equals` 与 `hashCode`；
10. 正则、金额、时间和 UUID 要由业务语义包进值类型。

必须掌握的是继承与组合的区别、接口与多态的执行方式、`enum`/`record`/`sealed` 各自解决的问题，以及 `equals` 与 `hashCode` 的绑定关系。

需要时查询的是重写的所有语言细则、默认方法冲突、sealed 的模块限制、模式匹配的具体语法版本、正则高级语法、时区转换和 `BigDecimal` 舍入规则。它们很重要，但不值得在没有具体需求时死记。

