---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.encapsulation-packages
title: 封装、访问控制与包边界
responsibility: 教授由类型维护自身不变量的可见性边界，不在本章教授继承复用或模块系统
volume: '02'
order: 4
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.encapsulation-packages.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.constructors-invariants
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
  text: 在 120 秒内解释封装、访问控制与包边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-encapsulation
  - java-package-boundary
  covers_topics:
  - java.private-public-protected
  - java.package-private
  - java.invariant-owner
  - java.import
  - java.package-access
  - java.api-internal-boundary
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：把设备领域类与调用端放入不同 package，以 private 字段和公开行为维护状态并验证 package-private 测试访问边界
  covers_topic_groups:
  - java-encapsulation
  - java-package-boundary
  covers_topics:
  - java.private-public-protected
  - java.package-private
  - java.invariant-owner
  - java.import
  - java.package-access
  - java.api-internal-boundary
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 public 可变字段、错误 import 和跨包访问 package-private，依据编译错误和不变量破坏修复
  covers_topic_groups:
  - java-encapsulation
  - java-package-boundary
  covers_topics:
  - java.private-public-protected
  - java.package-private
  - java.invariant-owner
  - java.import
  - java.package-access
  - java.api-internal-boundary
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 封装、访问控制与包边界

> 本章状态为 **drafting**。教材、实验和验证器可以使用，但自动输出不能代替独立解释，也不会自动改变 **PROGRESS.md**。

上一章让构造器保证设备一出生就有合法编码、名称和状态，但如果任何调用者都能直接写 **device.status = "WHATEVER"**，不变量会在创建后的第一秒被破坏。构造器只守住入口，封装要守住对象整个可观察生命周期。

**封装**不是机械地给每个字段生成 getter 和 setter，而是让拥有状态的类型同时拥有维护状态规则的权力；**访问控制**由编译器限制哪些代码能直接使用类型或成员；**包**为相关类型提供命名与一层可见性边界；**公开 API** 是外部调用者得到的稳定承诺，内部实现则应尽量留在边界内。

本章聚焦 **public、private、package-private**，并只给出 **protected** 的定位提示，因为它的完整语义与继承有关。不会讲 Java 模块系统、深反射、Spring 代理或序列化框架如何绕过访问边界。基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 本章完成证据

1. **解释证据**：120 秒内说明封装为何是“规则所有权”；区分 public、private 与省略修饰符；解释 package 和 import 的不同职责；给出 public 可变字段破坏不变量的反例。
2. **构建证据**：把 Device 放在领域包，把调用端放在另一个包；字段私有，只通过公开行为改变状态；同包辅助类型保持 package-private；固定断言证明合法路径。
3. **诊断证据**：复现私有字段跨类访问、package-private 跨包访问和错误 import 三种编译失败；再复现一个“代码能编译但 setter 让状态非法”的业务失败。

配套工件：

- [包与封装观察台](../../../examples/encyclopedia/ch.java-oop.encapsulation-packages/README.md)
- [FactoryCare 包边界实验](../../../labs/encyclopedia/ch.java-oop.encapsulation-packages/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.encapsulation-packages/README.md)

私有答案用于尝试后核对。禁止把答案目录并入公开路径，也不要通过把所有成员改成 public 来“修复”编译红线。

## 2. 从问题开始：谁可以让对象变坏

考虑：

~~~java
class Device {
    String code;
    String status;
}

Device pump = new Device("PUMP-01");
pump.status = "UNKNOWN_FROM_UI";
~~~

即使构造器把初始状态设为 **REGISTERED**，调用者仍可直接写任意文本。此时错误规则分散在每一个页面、脚本和服务中：A 调用者记得检查，B 调用者忘了；将来增加状态，所有位置都要同步。

封装后的外形：

~~~java
public class Device {
    private String status;

    public void startRepair() {
        if (!"REGISTERED".equals(status)) {
            throw new IllegalStateException("device cannot start repair");
        }
        status = "IN_REPAIR";
    }

    public String status() {
        return status;
    }
}
~~~

外部不能随意写字段，只能请求 **startRepair**。对象根据自身当前状态判断请求是否合法。公开行为表达业务意图，字段布局成为可修改实现。

## 3. 封装的直觉模型：状态与规则由同一边界拥有

把对象想成带受控面板的设备柜：

- 私有字段是柜内元件；
- 公开方法是经过设计的按钮与读数；
- 构造器是上电验收；
- 包内辅助代码是同一维护区域的协作者；
- 包外调用者只能依赖公开面板。

这个比喻不表示 private 是安全保险箱。拥有 JVM 进程权限的反射、调试器或本机代码可能观察内部；序列化框架也可能有特殊机制。访问控制首先是语言和编译期设计边界，不代替认证、授权、数据库权限或加密。

一个好的边界回答：

1. 哪个类型拥有某条不变量？
2. 外部真正需要发起哪些业务请求？
3. 外部需要读取什么结果，而不是读取所有内部字段？
4. 哪些辅助细节可在包内变化？
5. 哪些错误应编译失败，哪些请求应运行时被拒绝？

## 4. 四种成员访问级别的最小地图

Java 类成员可以声明不同访问级别：

| 写法 | 同一个类 | 同一个包其他类 | 不同包普通类 | 本章定位 |
| --- | --- | --- | --- | --- |
| **private** | 可以 | 不可以 | 不可以 | 对象内部实现 |
| 无修饰符 | 可以 | 可以 | 不可以 | package-private 包内协作 |
| **protected** | 可以 | 可以 | 受继承相关规则限制 | 只认识名称，继承章详讲 |
| **public** | 可以 | 可以 | 可以 | 对外承诺 |

“无修饰符”不是 public，也不是 private；它通常称为 **package-private** 或“包访问”。Java 源码中没有 **package-private** 这个关键字。

访问判断依赖声明位置和访问者位置，不依赖对象来自哪里。例如包外代码即使拿到了 Device 引用，也不能直接访问它的 private 字段；同包另一个类也不能访问 private，只能访问 package-private 或 public。

### 4.1 顶层类型的限制

顶层类通常只能是 public 或 package-private，不能写 private。一个 public 顶层类通常需要放在同名 **Device.java** 文件中。package-private 顶层类可以作为包内实现：

~~~java
package com.factorycare.device;

final class DeviceCodePolicy {
    // 只供本包协作，不构成跨包 API。
}
~~~

本章不讲嵌套类的 private 规则；先把顶层文件和包边界练熟。

## 5. package 声明：类型的完整名字

源文件开头可以声明包：

~~~java
package com.factorycare.device.domain;

public class Device {
}
~~~

这个类的完全限定名是 **com.factorycare.device.domain.Device**。包名帮助避免同名冲突，也把类型组织到可见性边界中。常见目录布局与包名对应：

~~~text
src/
└── com/
    └── factorycare/
        └── device/
            └── domain/
                └── Device.java
~~~

语言规范关注声明的包名；构建工具和编译命令依靠约定从目录找到源码、把 class 输出到相应层级。初学时让目录与包逐段一致，可以减少“文件能看见但类型找不到”的错误。

不要在正式项目使用未命名包。未命名包适合最小一次性示例，却无法形成清晰的跨包结构，具名包中的代码也不能按普通方式导入未命名包类型。

## 6. javac -d：从源码路径得到类输出

给定两个源文件：

~~~text
src/com/factorycare/device/domain/Device.java
src/com/factorycare/device/app/Main.java
~~~

可从工件根目录编译：

~~~bash
javac --release 25 -d build/classes \
  src/com/factorycare/device/domain/Device.java \
  src/com/factorycare/device/app/Main.java
java -cp build/classes com.factorycare.device.app.Main
~~~

参数 **-d build/classes** 告诉编译器把类文件写入输出根目录，编译器按包名建立子目录。运行时使用完全限定类名。不要把 class 文件混回 src；源码与构建产物分开，清理和版本控制才可预测。

出现 **wrong class**、**duplicate class**、**package ... does not exist** 时，按顺序检查：

1. package 声明是否拼写正确；
2. import 与使用的完全限定名是否一致；
3. 源文件是否在本次 javac 输入中；
4. **-d** 输出目录和 **-cp** 运行类路径是否对应；
5. 是否残留旧 class 干扰；
6. 文件名是否与 public 顶层类一致。

## 7. import：名字解析便利，不授予访问权限

包外调用者可以导入 public 类型：

~~~java
package com.factorycare.device.app;

import com.factorycare.device.domain.Device;

public class Main {
    Device current;
}
~~~

import 让源码可写简单名 **Device**，本质上协助编译器解析类型名。它不会：

- 复制类；
- 下载依赖；
- 执行类；
- 让 private 成员变 public；
- 让 package-private 类型跨包可见；
- 自动把源码加入编译命令。

也可以直接写完全限定名而不 import：

~~~java
com.factorycare.device.domain.Device current;
~~~

**java.lang** 中常用类型会被自动导入，所以 String 不需要显式 import。两个包都有同名 Device 时，不能用两个单类型 import 同时取得同一个简单名；至少一个位置使用完全限定名，或者重新审视命名。

星号 import 只影响指定包中的类型简单名，不递归导入子包。包名相似不代表父子权限关系：**com.a** 与 **com.a.internal** 是不同包，后者不会自动拥有前者的 package-private 权限。

## 8. private 字段：隐藏表示，保留行为

最小领域类：

~~~java
package com.factorycare.device.domain;

public class Device {
    private final String code;
    private String status;

    public Device(String code) {
        this.code = requireText(code);
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
~~~

本章只借用 **final** 表达 code 不再重新赋值，完整不可变性在后章。关键是：外部能读取必要结果和请求合法变化，却不能直接写 status。以后 status 从 String 改为 enum，调用者只要依赖的公开行为不变，迁移面就更小。

### 8.1 private 不等于“不能测试”

测试应通过公开行为验证不变量：

- 构造后 status 为 REGISTERED；
- startRepair 后为 IN_REPAIR；
- 再次 startRepair 被拒绝；
- 没有公开入口能写任意状态。

不要为了让测试方便而把字段改 public。若测试必须知道实现细节，先问它是在验证业务契约，还是把当前字段布局锁死。

## 9. getter 与 setter 不是封装的自动答案

下面的类字段虽然 private，规则仍然外泄：

~~~java
public void setStatus(String status) {
    this.status = status;
}
~~~

任何调用者都能写 null、空白或未知状态。它只是把直接字段赋值换成一次方法调用，没有表达允许的状态迁移。

优先使用意图明确的命令：

~~~java
public void assign() { ... }
public void startRepair() { ... }
public void completeRepair() { ... }
~~~

查询也应返回调用者需要的视图：

~~~java
public boolean isUnderRepair() {
    return "IN_REPAIR".equals(status);
}
~~~

不是所有 setter 都错误。配置对象或简单数据载体可能有合法的可写属性，但也要定义输入范围、生命周期和调用者。领域对象出现全字段 setter 时，应逐个问：调用者为何有权任意改变这项状态？规则应该属于谁？

### 9.1 getter 也可能泄漏可变内部状态

返回 String、数字等不可变值通常不会让调用者修改对象内部。但若字段是数组，直接返回引用会破坏封装：

~~~java
private int[] readings;

public int[] readings() {
    return readings; // 调用者可改数组元素
}
~~~

最小防御方式：

~~~java
public Device(int[] readings) {
    this.readings = readings.clone();
}

public int[] readings() {
    return readings.clone();
}
~~~

输入时复制，防止调用者保留别名后修改；输出时复制，防止读取者改内部数组。复制会有成本，真实设计还要考虑数据量和只读视图；本章只建立“private 字段若把可变引用原样返回，边界仍然破了”的直觉。

## 10. package-private：有意的包内协作

设备编码规范化器可以只供领域包使用：

~~~java
package com.factorycare.device.domain;

final class DeviceCodePolicy {
    static String normalize(String raw) {
        return raw.trim().toUpperCase();
    }
}
~~~

省略 public 后，包外不能使用该顶层类，同包 Device 可以使用。这样公开 API 保持小，内部实现可以一起演进。

package-private 不是“懒得写修饰符”。每次省略都应有意图：

- 类型是否只服务本包？
- 同包所有代码都应该有访问权吗？
- 包是否足够内聚，还是成了几十个无关类的权限大桶？
- 测试放同包访问内部，是在验证必要协作，还是绕过公开契约？

包内权限是编译边界，不是团队权限。把恶意代码放进同一包就可能使用包内成员；依赖来源和构建安全仍需单独治理。

## 11. API 与 internal 边界

可以把包分为：

~~~text
com.factorycare.device.api
com.factorycare.device.domain
com.factorycare.device.internal
com.factorycare.device.app
~~~

但包名含 **internal** 并不会自动产生特殊权限；真正约束来自 public 与 package-private。若 internal 子包中的类声明为 public，普通 Java classpath 上的其他包仍能访问它。Java 模块系统能进一步控制导出，但不属于本章。

因此当前阶段使用两层策略：

1. public 只给真正跨包依赖的最小类型和行为；
2. 包内辅助类型省略 public；
3. 目录与名称表达意图；
4. 编译失败案例验证跨包边界；
5. 文档明确哪些 API 承诺稳定。

不要创建一个 **util** 包并把所有方法设 public。工具类一旦被到处依赖，内部实现就很难变化。

## 12. protected 只建立定位，不提前学继承

protected 成员在同包可访问；跨包时还涉及子类身份和访问表达式规则，不能简化成“给子类的 public”。完整语义必须结合继承与接收者类型学习。

本章看到 protected 时只做两件事：

- 知道它不是 package-private，也不是普通跨包 public；
- 暂不把它用于 Device 设计。

为“以后可能继承”提前把字段设 protected，会把对象表示暴露给未知子类，通常比 private 更难维护。默认先 private，通过公开或受控行为表达契约；继承章节再根据真实扩展点判断。

## 13. 编译诊断：三种红线不是同一问题

### 13.1 private 跨类访问

~~~text
status has private access in Device
~~~

先确认访问代码真正需要什么。若它想发起状态变化，调用业务方法；若只需显示，提供只读查询。不要直接把字段改 public。

### 13.2 package-private 跨包访问

~~~text
DeviceCodePolicy is not public ... cannot be accessed from outside package
~~~

这可能是预期边界。把调用逻辑移到领域公开行为，或重新判断这个能力是否真的应成为公共 API。不能仅因测试方便就扩大权限。

### 13.3 import 或包名错误

~~~text
package com.factorycare.devices.domain does not exist
cannot find symbol: class Device
~~~

错误 import 与不可访问有时连续出现。先看第一条可信编译错误和源位置，核对完全限定名；不要在 pom 或网络依赖中盲目搜索一个本地拼写错误。

## 14. “能编译但封装失败”的诊断

访问控制只能阻止某些源码访问，不能判断业务方法设计是否正确：

~~~java
public void changeStatus(String value) {
    this.status = value;
}
~~~

这段 public 方法完全合法，却让外部绕过状态迁移。诊断需要业务断言：

1. 写出允许的前置状态；
2. 调用公开行为；
3. 断言成功后的状态；
4. 以非法顺序调用，确认被拒绝；
5. 搜索是否还有通用写入口；
6. 变更需求时只修改不变量拥有者。

所以验证必须同时包含编译失败和运行断言。只测“跨包字段访问会红”不能证明公开 API 安全；只测快乐路径也不能证明边界存在。

## 15. 包结构中的测试位置

测试可以放在与被测类相同包名，哪怕目录位于测试源码树；此时它可访问 package-private。这样适合验证包内协作，但容易让测试依赖内部细节。还应保留跨包调用测试，从真实消费者视角只使用 public API。

一个双视角策略：

- **同包测试**：必要时验证 package-private 策略协作；
- **包外测试**：验证公开构造器、命令和查询；
- **预期编译失败**：证明 private/package-private 不能越界；
- **运行断言**：证明公开行为维护不变量。

本章 shell 验证器会把故障源码保留为 **.java.txt**，单独复制后调用 javac，并要求非零退出及目标诊断片段。它们不能混入正例编译集合。

## 16. FactoryCare 设计切片

建议最小布局：

~~~text
src/
└── com/factorycare/workorder/
    ├── domain/
    │   ├── WorkOrder.java
    │   └── StatusPolicy.java
    └── app/
        └── WorkOrderConsole.java
~~~

WorkOrder 是 public 领域类型；StatusPolicy 可以 package-private；字段 private；app 只能调用公开行为：

~~~java
WorkOrder order = new WorkOrder("WO-1001");
order.assign("TECH-07");
order.start();
System.out.println(order.status());
~~~

调用端不能写 **order.status = "CLOSED"**，也不能导入包内 StatusPolicy。这样状态机规则将来改变时，调用端不需要知道字段如何保存。

仍需保持边界诚实：

- Java private 不代表数据库行只能当前用户查看；
- package 不代表租户隔离；
- public 方法不代表 HTTP 接口已授权；
- getter 不代表可以把内容返回前端；
- 日志输出仍需脱敏。

## 17. TypeScript 与 Vue 对照

TypeScript 的 **private** 主要由类型检查器约束，编译成 JavaScript 后的运行时边界取决于输出与用法；JavaScript 的 **#field** 才是不同的运行时私有字段机制。Java private 由 Java 编译器与运行时访问规则支持，但反射等受控机制另有规则。不要用“它们都叫 private”推导完全相同的安全保证。

模块的 **export** 更像“这个名字能否从模块导入”，与 Java package-private 有可迁移直觉，但解析、打包和运行时模型不同。Vue 组件中 props 是输入、emit 是对外事件、expose 是显式暴露；父组件不应直接篡改子组件内部 ref。共同原则是缩小公共表面、让拥有状态的一方维护规则。

适度对照：

| Java | TypeScript/Vue 直觉 | 不能机械等同之处 |
| --- | --- | --- |
| private 字段 | 类内部状态、组件内部 ref | 编译与运行时机制不同 |
| public 方法 | 导出函数、组件事件入口 | 生命周期与对象模型不同 |
| package-private | 未导出的内部协作 | JS 模块与 Java 包解析不同 |
| import | ES import 的名字引入 | Java import 不加载 npm 依赖 |

## 18. 安全与维护边界

封装改善可维护性，但必须避免过度承诺：

- private 防止普通源码直接访问，不是加密；
- public 查询返回敏感字段前仍需授权与脱敏；
- 防御性复制防止引用别名修改，不限制数据被合法调用者读取后传播；
- package 名称不是安全域；
- 反序列化输入仍需校验；
- 访问修饰符不能防 SQL 注入、越权或跨租户查询；
- 输出异常时不要泄露内部包路径与敏感值给最终用户。

安全评审应问“谁是调用者、在哪个进程、经过什么授权、数据最终去了哪里”，不能只问字段是否 private。

## 19. AI 协作审查清单

AI 很容易生成“Lombok Data 风格”全字段 getter/setter，或为解决测试编译把成员全部 public。接受代码前逐项检查：

1. 每个 public 成员的真实消费者是谁？
2. 通用 setter 是否绕过业务动作？
3. getter 是否返回可变数组或对象别名？
4. package 声明与目录是否一致？
5. import 是名字错误还是缺依赖？
6. package-private 是有意边界还是遗漏修饰符？
7. 测试是通过公开行为验证，还是偷看内部字段？
8. 修复编译错误是否不必要地扩大 API？
9. 敏感字段是否被 toString 或日志公开？

让 AI 给补丁时限制为一个边界变化，并要求它写出迁移影响。不要用“项目能跑”作为扩大可见性的理由。

## 20. 预测—构建—破坏—变更

### 20.1 预测

在运行前判断：

- 同包类能否访问另一个类的 private 字段；
- 跨包类能否访问省略修饰符的方法；
- import 一个 package-private 类能否获得权限；
- **com.a** 是否与 **com.a.internal** 属同一包；
- 返回 private int[] 字段后，调用者改元素是否影响对象；
- 把字段 private 后，哪个调用点会先编译失败。

### 20.2 构建

创建 domain 与 app 两个包。Device 字段全部 private；公开构造器接收编码；公开 **startRepair/status/code**；包内 **DeviceCodePolicy** 规范化编码。使用 **javac --release 25 -d build/classes** 编译并以完全限定类名运行。

### 20.3 故意破坏

一次只做一项：

1. app 直接访问 private status；
2. app import package-private DeviceCodePolicy；
3. 把 import 的 **device** 拼成 **devices**；
4. 加入 **setStatus(String)** 并写 UNKNOWN；
5. getter 原样返回数组；
6. 把包声明改了却不改调用端。

分别记录编译阶段或运行阶段、首条可信证据、最小修复与复跑结果。

### 20.4 需求变更

新增规则：维修中设备不能再次开始维修，只能完成或取消。先通过公开测试表达规则，再修改 Device；调用端不应读取 status 后自行 if 决定，因为两个调用者会重复规则。第二个变更：公开展示只需要末四位设备编码，新增脱敏查询而不是暴露整个内部对象。

## 21. 无 AI 独立训练

限时 60 分钟：

1. 从空目录建立两个 package；
2. 写一个 public Device 和一个 package-private Policy；
3. 字段 private，公开 API 不超过构造器、两个查询、两个命令；
4. 写十个运行断言；
5. 写 private 与 package-private 两个预期编译失败；
6. 制造错误 import 并按日志定位；
7. 把数组 getter 写坏，再用别名测试证明并修复；
8. 120 秒复述 import 为什么不授予权限。

禁止把成员改 public、移动到同一包或删除故障源码来让命令变绿。修复必须保留既定边界。

## 22. 高频误区

1. **“private 就是封装完成。”** 公开通用 setter 仍可破坏规则。
2. **“getter/setter 越全越标准。”** 公共 API 应由需求驱动。
3. **“省略修饰符就是默认 public。”** 它是 package-private。
4. **“import 以后就能访问。”** import 只帮助名字解析。
5. **“子包属于父包。”** Java 可见性中它们是不同包。
6. **“目录相同就一定同包。”** 权威身份来自 package 声明与编译上下文。
7. **“package-private 关键字要写出来。”** Java 没有该关键字。
8. **“protected 是给所有子类的 public。”** 跨包语义更严格，继承章再学。
9. **“private 数组 getter 是安全的。”** 返回原引用会泄漏可变状态。
10. **“包名 internal 就禁止外部访问。”** 名称表达意图，不自动执法。
11. **“编译通过证明不变量安全。”** 还需运行时业务断言。
12. **“Java private 等于权限系统。”** 它不代替用户授权、租户隔离或加密。

## 23. 复习计划

- 当天：画访问矩阵，口述 package 与 import；
- 第 2 天：从空目录重建双包示例，制造两个编译失败；
- 第 7 天：把通用 setter 改为业务命令并写非法顺序测试；
- 第 14 天：加入数组字段，验证输入输出防御性复制；
- 第 30 天：审查一个 Vue 或 Spring 项目的公共表面，列出可缩小的 API，但不擅自重构。

复习必须保留红线证据。只阅读访问矩阵会造成“看见答案会选，换目录不会排错”的假熟练。

## 24. 一页速查

| 写法或问题 | 最小结论 |
| --- | --- |
| **private** | 仅声明它的顶层类体边界内按规则访问 |
| 无修饰符 | package-private，同包可见 |
| **public** | 普通跨包调用可见，构成 API 候选 |
| **protected** | 含同包与继承规则，本章不展开 |
| **package a.b;** | 声明类型所在包 |
| **import a.b.Type;** | 引入简单名，不授予权限 |
| **javac -d out** | 按包结构输出 class |
| **java -cp out a.b.Main** | 用完全限定类名运行 |
| private 字段 + setAny | 语法隐藏但业务边界可能仍破 |
| 意图方法 | 由对象集中维护状态迁移 |
| 返回可变字段引用 | 会泄漏内部状态 |
| 输入输出复制 | 防止外部别名修改内部数组 |
| **a.b** 与 **a.b.internal** | 两个不同包 |
| public 顶层类 | 通常文件名与类名一致 |

## 25. 术语表

- **封装**：把状态表示和维护规则放进明确边界，只公开必要操作。
- **访问控制**：由语言规则限制类型或成员可从哪些位置访问。
- **public**：允许普通跨包访问的修饰符。
- **private**：把成员限制在声明类内部的修饰符。
- **package-private**：省略访问修饰符形成的包内访问级别。
- **protected**：具有同包和继承相关规则的访问级别。
- **包**：类型命名空间与包访问边界。
- **完全限定名**：包含包名的完整类型名。
- **import**：使源码可用简单名引用其他包类型的声明。
- **公共 API**：外部调用者被允许依赖的类型、构造器和成员集合。
- **内部实现**：可在边界内变化、不应被外部直接依赖的细节。
- **不变量拥有者**：负责验证并维护某条对象规则的类型。
- **防御性复制**：在边界复制可变数据，避免共享引用绕过封装。
- **表示泄漏**：内部可变对象引用被外部取得并可直接修改。

## 26. 本章边界与官方来源

本章要求能用 private、package-private 与 public 设计最小 API；让目录、package、import、javac 输出和运行类名一致；用业务行为维护不变量；诊断跨类和跨包访问；识别 getter/setter 与可变引用泄漏。protected 的继承细节、Java Platform Module System、深反射和框架访问留到后续。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [JLS 25 §6.6 Access Control](https://docs.oracle.com/javase/specs/jls/se25/html/jls-6.html#jls-6.6)：类型与成员访问控制。
- [JLS 25 §7.4 Package Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-7.html#jls-7.4)：具名包与包声明。
- [JLS 25 §7.5 Import Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-7.html#jls-7.5)：单类型、按需与静态 import 的名字规则。
- [JLS 25 §8.1.1 Class Modifiers](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.1.1)：顶层与成员类修饰符。
- [JLS 25 §8.3 Field Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.3)：字段声明与访问修饰符。
- [javac 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：**--release**、**-d**、类路径与诊断选项。
- [java 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html)：类路径和完全限定主类运行方式。

稳定核心是“最小公开表面、明确规则所有权、编译边界与运行断言共同证明封装”。工具诊断文字可能随补丁变化，包和访问语义不随之改变。
