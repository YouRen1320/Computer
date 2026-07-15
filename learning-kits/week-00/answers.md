# Week 00 独立答案册

> **警告：考前勿看。** 先在关闭 AI 的条件下完成[assessment.md](./assessment.md)并保存答案。这里提供评分要点和一种排查路径，不替代你机器上的实际证据。

## A. 工具链图参考

```text
Terminal
  └─ 启动 zsh（加载相应配置）
      └─ 解析 mvn：alias/function/builtin/PATH
          └─ 启动 Maven 3.9.16
              ├─ 根据 JAVA_HOME/启动脚本找到 JDK 25
              ├─ 读取 pom.xml
              ├─ 调用编译插件，以 javac 编译源码/测试
              └─ 调用 Surefire，在 JVM 中运行 JUnit 测试
```

关键点：`java -version` 是当前 shell 对 `java` 的解析结果；Maven 可能由启动脚本、`JAVA_HOME`、IDE Runner 或别的环境启动。真正判断 Maven 使用哪个 JDK，要看 `mvn -v` 和实际构建日志。

旧终端是已经存在的进程，环境变量通常在进程创建时继承。修改配置文件不自动重写旧进程环境。新开符合相同启动类型的 shell 后再验证。

IDE 自身运行时可以与项目 JDK 不同；项目编译 SDK、Maven Runner 和测试 Runner 应与锁定基线一致并可验证。

## B. 故障诊断参考路径

### 合理假设

1. `PATH` 中存在多个 `java`/`mvn`，当前命中顺序与预期不同；
2. `JAVA_HOME` 指向另一发行版或旧 JDK；
3. Maven 是从另一环境启动，或 IDE Maven Runner 单独指定 JDK；
4. 旧 shell 没有加载新配置；
5. alias/function 包装了命令。

### 最小取证

```bash
type -a java javac mvn
echo "$JAVA_HOME"
echo "$PATH"
/usr/libexec/java_home -V
java -version
javac -version
mvn -v
```

如果终端已一致而 IDE 不一致，应查看 Project SDK、Maven Runner/Test Runner 和构建日志，而不是再次修改 shell。

### 判定方式

- `type -a` 证明有哪些候选以及当前解析对象；
- `mvn -v` 证明 Maven 当前进程实际 Java home；
- 新 shell 复验可区分旧进程环境；
- IDE 构建日志证明 IDE 启动链路；
- 改完必须重复同一组证据命令。

“已修改配置”不是“已解决”；“版本输出与路径一致并且测试通过”才是验证结果。

## C. Maven/JUnit 烟雾题要点

一个足够小的生产方法可以是：

```java
package com.factorycare.baseline;

public final class DurationCalculator {
    private DurationCalculator() {}

    public static int totalMinutes(int first, int second) {
        if (first < 0 || second < 0) {
            throw new IllegalArgumentException("minutes must be non-negative");
        }
        return Math.addExact(first, second);
    }
}
```

对应测试至少包含正常、零边界和非法值。断言失败时，源码通常已经编译，Surefire/JUnit 报告具体测试失败；编译错误则在测试执行前停止，并给出源文件行号和符号/语法信息。

测试点：

- `10 + 20 = 30`；
- `0 + 0 = 0`；
- 负数抛出 `IllegalArgumentException`；
- 如果主动测试极端整数，可验证溢出策略，而不是让结果静默回绕。

常见错误：为了烟雾测试加入 Spring；测试只写 `assertTrue(true)`；失败后删除测试；只在 IDE 运行、不验证命令行。

## D. 安全题参考

至少包括：

- 远程内容会变化，管道执行前没有审阅；
- 未验证域名、TLS、签名或哈希；
- 脚本可能修改 shell、PATH、启动项或下载二进制；
- `sudo` 把影响提升到系统范围；
- 没有变更前快照和回滚；
- `settings.xml` 可能含仓库凭据、代理用户名密码或内部地址；
- shell 配置可能含 token、私有路径和公司信息；
- AI 回答可能基于过期版本。

安全替代流程：从官方安装页确认来源；下载到文件先读；验证签名/哈希（若官方提供）；明确写入位置；备份配置；尽量用户级安装；单步执行；新终端复验；保存回滚；只向 AI 提供脱敏的必要片段。

## E. 基线与简历参考

“Flutter SDK 当前未安装，基于 2025 年旧 App 代码完成口述审查，未运行；计划 Week 34 安装 stable 并做真机验收”是有效记录。“Flutter 应该没问题，按熟练计分”无证据。

事实型表达示例：

```text
不合格：精通 Java 企业级开发。
合格：使用 Java 25 与 JUnit 完成纯 Java 规则练习和自动化测试，当前处于基础阶段。
```

40 个岗位样本可以描述“此样本中哪些关键词重复出现、各类别占比、后续验证方向”；不能证明全部南昌市场、真实录用门槛或未来趋势。

## 口述题要点

- LTS 是维护策略；stable 是发布成熟度；RC 接近正式但仍可能变化；preview API 未来可能变化并需特殊启用；
- `PATH` 决定命令查找，`JAVA_HOME` 指向 JDK 根目录，二者可不一致；
- `pom.xml` 声明项目模型，Maven 本地仓库缓存依赖/插件；
- 未来工具按真实阶段安装能减少冲突面，本周记录触发条件即可；
- Git只跟踪仓库文件，无法自动回滚系统软件和外部 IDE 状态；
- AI 可以解释、比较和审查命令，人必须决定来源、执行、验证和回滚。

## 自评分校准

若答案只是背出命令但无法根据输出提出假设，B 项不应超过 18/30。若没有真实运行烟雾测试，C 项最高 8/20。若简历仍含无法证明的“熟练/精通”，E 项最高 7/15。

## 面试校准

> 先提交[面试题](./interview.md)的独立回答再阅读。以下要点必须替换为你自己的本机证据。

1. **JDK/JRE/JVM**：JVM 加载并执行字节码；JRE 是运行 Java 程序所需环境的概念；JDK 包含编译、打包和诊断等开发工具。高层链路是 `.java → javac → .class → JVM`。
2. **PATH/JAVA_HOME**：PATH 决定 shell 解析命令的顺序，JAVA_HOME 指向 JDK 根。shell、Maven、IDE Runner 可能选择不同来源，必须交叉查看路径和版本。
3. **JDK 25 LTS**：选择理由是支持周期、团队稳定和框架兼容，不是“永不升级”。仍需跟进同大版本维护补丁并做构建/测试验证。
4. **版本冲突诊断**：先用 `type -a`、PATH、JAVA_HOME、`java/javac -version`、`mvn -v` 取证，再检查旧 shell 和 IDE/Maven Runner。一次只改一个因素，新终端复验；不直接重装。
5. **Maven 边界**：POM 描述项目、依赖、插件和构建；本地仓库缓存 artifact。损坏时先定位具体 artifact、镜像、校验或网络问题，不无条件删除全部缓存。
6. **三类反馈**：编译错误发生在生成可执行字节码前；运行时异常出现在执行路径；测试失败是可执行测试与预期不符或异常。分别看编译器位置、异常堆栈首个业务帧、失败测试名与断言差异。
7. **IDE 差异**：IDE 可能有独立 Project SDK、Maven importer/runner、测试 Runner 和环境继承。用设置与构建日志证明选择，再在终端和 IDE 各运行一次测试。
8. **可复现环境**：记录来源、精确版本、wrapper/lockfile、验证命令、CI 基线、配置变更和回滚。README 只是入口，实际构建与测试才是运行证据。
9. **远程脚本**：风险包括内容变化、域名/供应链、权限、写入范围与回滚。即使官方提供，也应确认域名和动作，必要时先下载审阅/验证哈希，按最小权限单步执行。
10. **Git 边界**：能回滚受跟踪仓库文件，不能自动回滚系统包、进程环境、IDE 设置和外部服务。用备份、安装记录、版本管理器与恢复步骤补足。
11. **按需安装**：没有真实用例时一次安装会扩大冲突面和维护成本。JDK/Maven 是 Week 01 阻塞，所以优先；数据库、移动和 AI 工具到使用周次再锁定与验证。
12. **AI 接管能力**：人定义范围与验收，AI 解释或生成小切片，人工审 diff、运行成功/失败测试、无 AI 复述和修改、可回滚提交。案例尚未发生时必须说“这是计划中的验证”，不能伪造一次 AI 错误。
13. **岗位样本边界**：只能描述样本内频率与方向；按日期、城市、类别、必选/加分和重复 JD 分层，并持续滚动采样，不能外推全部南昌市场或录用门槛。
14. **简历事实**：Week 00 不能写“熟练 Java”。只能描述真实环境、烟雾测试和当前学习阶段；达到 L2/L3 后仍以具体行为、测试和取舍表达，而不是堆形容词。

压力题可用结构：承认 AI 的具体使用范围；说明自己负责的目标、边界与决策；展示真实失败测试和修复，或明确案例尚未发生；愿意现场无 AI 修改规则。不要声称每个字符都手写，也不要把责任推给模型。
