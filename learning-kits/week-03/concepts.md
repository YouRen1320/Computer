# Week 03 系统讲义

## 1. 类与对象

```java
final class Device {
    private final String id;
    private String name;
    private boolean enabled;
}
```

- class 定义类型、状态和行为；
- object 是运行时实例；
- reference variable 保存指向对象的引用值；
- `new` 分配对象并调用构造器；
- 多个引用可以指向同一对象；
- `null` 没有对象，解引用触发 NPE。

TS class 可帮助理解语法；失效处是 Java 的访问、package、构造/字段、运行时类型、继承和框架规则不同。

## 2. 字段、局部变量与 this

- field 属于对象/类，有默认值；
- local variable 属于方法调用，读取前必须初始化；
- 参数是局部变量；
- `this` 表示当前实例；static 上下文没有 this；
- `this.name = name` 区分字段与参数；
- instance method 隐式操作当前实例；
- 不要用 getter/setter 自动暴露所有状态。

## 3. 构造器建立有效对象

```java
Device(String id, String name) {
    if (id == null || id.isBlank()) {
        throw new IllegalArgumentException("id is required");
    }
    this.id = id;
    rename(name);
    this.enabled = true;
}
```

- 构造器无返回类型；
- 声明任何构造器后编译器不再自动给无参构造器；
- `this(...)` 委托到另一个构造器；
- 一个主初始化路径避免规则分叉；
- 构造器不做远程 I/O、不启动线程、不发布半成品；
- static factory 可以用名字表达 `createEnabled` 等入口，本周不做复杂缓存/实现选择。

## 4. 封装是不变量，不是 getter/setter

不变量是在对象整个有效生命周期必须成立的事实。例如：

- id/name 非空；
- disabled device 不能被再次 disable 而静默产生错误审计；
- 工单号创建后不能随意修改；
- 分配技师时 assignee 非空。

行为方法：`rename`、`disable`、`assignTo`。它们验证前置条件、原子更新、保留合法后置状态。

贫血数据袋暴露 setter，调用者可绕过规则；另一个极端是把所有服务/数据库/邮件塞实体。职责按业务变化和依赖边界决定。

## 5. 访问控制与 package

- private：仅当前类；
- package-private：同 package；
- protected：同 package + 子类相关访问，Week 04 深入；
- public：所有可见调用者；
- 顶层类只能 public 或 package-private；
- 采用最小可见性；
- 测试同 package 能访问 package-private，不需要将内部 API public；
- private 不等于安全授权。

## 6. static 与实例

```java
private static final int MAX_ASSIGNMENTS = 5;
```

- static 属于类；instance 属于每个对象；
- 常量、经典 main、无状态纯帮助方法可以 static；
- mutable static field 是全进程共享，会造成测试顺序、并发和多租户污染；
- 不为“通过类名调用方便”把领域状态写 static；
- static 的前后可见性修饰符顺序是风格，不是“static 后必须 public/private”。

## 7. final 与不可变

- final 变量只能赋值一次；
- final reference 不能改指向，引用对象仍可能修改；
- immutable class 需要所有可观察状态不可变、构造防御复制、返回不泄漏；
- private final 数组仍需复制；
- class final 防继承在 Week 04 联动理解；
- `static final` 常量不应指向可被外部修改的数组/集合。

## 8. 引用泄漏与复制

```java
final class Checklist {
    private final String[] items;

    Checklist(String[] items) {
        this.items = Arrays.copyOf(items, items.length);
    }

    String[] items() {
        return Arrays.copyOf(items, items.length);
    }
}
```

数组复制时间/空间 O(n)。若仅保存引用是 O(1)，但外部可破坏内部状态。设计按安全/性能/数据规模衡量。

## 9. 对象行为测试

测试：

- 有效构造；
- 每条无效构造；
- 行为前后状态；
- 重复/非法行为；
- 异常后状态未半更新；
- 输入/输出数组引用泄漏；
- 多个实例不会共享 mutable static 状态。

不要只测 getter 等于构造参数；核心是规则。

## 常见误区

- 把 class 当字段袋；
- 构造器加 `void` 变普通方法；
- 为框架预先加 public 无参构造/所有 setter；
- final List/array 当深不可变；
- mutable static 保存计数/当前用户；
- 返回内部数组；
- 在构造器调用可被子类重写的方法（Week 04 解释风险）；
- 为每个字段创建 getter/setter 而没有行为语言。
