---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.configuration-profiles
title: 配置属性、Profile、环境覆盖与敏感配置
responsibility: 教授外部配置来源、优先级和类型绑定，不把 Profile 用作任意业务分支或秘密存储
volume: '05'
order: 4
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.configuration-profiles.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.beans-lifecycle-scopes
version_surfaces:
- spring-framework-7
- spring-boot-4.1
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
  text: 在 120 秒内解释配置属性、Profile、环境覆盖与敏感配置的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-configuration
  - spring-profile-secret
  covers_topics:
  - spring.property-source-order
  - spring.configuration-properties
  - spring.environment-override
  - spring.profile
  - spring.secret-configuration
  - spring.config-validation
  uses_capabilities:
  - java.encapsulation-immutability
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：定义类型安全 FactoryCareProperties，分别从默认文件、Profile、环境变量覆盖并在启动时校验必填项
  covers_topic_groups:
  - spring-configuration
  - spring-profile-secret
  covers_topics:
  - spring.property-source-order
  - spring.configuration-properties
  - spring.environment-override
  - spring.profile
  - spring.secret-configuration
  - spring.config-validation
  uses_capabilities:
  - java.encapsulation-immutability
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入属性名拼错、优先级误判和秘密写入仓库，读取绑定报告后修复并改用外部秘密来源，并把异常定位到第一处可信证据
  covers_topic_groups:
  - spring-configuration
  - spring-profile-secret
  covers_topics:
  - spring.property-source-order
  - spring.configuration-properties
  - spring.environment-override
  - spring.profile
  - spring.secret-configuration
  - spring.config-validation
  uses_capabilities:
  - java.encapsulation-immutability
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# 配置属性、Profile、环境覆盖与敏感配置

> 本章状态为 drafting。正文和工件只提供教材证据，不自动更新 PROGRESS.md，也不表示学习者已经完成 Week 09/10。

同一份应用代码需要在本地、测试和生产使用不同地址、超时与凭据。把这些值写死在 Java 类里会迫使每个环境重新编译，也会让秘密进入仓库。Spring Environment 汇总多个 PropertySource，Spring Boot 再提供 config data、宽松名称绑定、类型转换和 ConfigurationProperties 校验。

本章固定 Spring Boot 4.1.0、其 BOM 管理的 Spring Framework 7.0.8、JDK 25 与 Maven 3.9.16。Boot 4.1.0 已由官方发布并支持 JDK 25；工件不启动 Web 服务器。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要能预测同一键在默认文件、Profile 文件、环境变量和命令行同时出现时的最终值，并指出来源。还要把字符串绑定为 Duration、整数和嵌套对象，在缺秘密、数值越界或键拼错时让 context 启动失败。

配套工件：

- [外部配置与类型绑定观察台](../../../examples/encyclopedia/ch.spring.configuration-profiles/README.md)
- [优先级、Profile、校验与漂移实验](../../../labs/encyclopedia/ch.spring.configuration-profiles/README.md)
- [PropertySource 优先级练习](../../../exercises/encyclopedia/ch.spring.configuration-profiles/README.md)

## 2. 什么是应用配置

应用配置是部署者在不改业务源码的前提下选择的运行参数，例如外部 API 地址、超时、重试上限、功能基础设施实现和凭据引用。它不同于工单状态规则、价格算法或权限判断，后者属于业务代码和数据合同。

不是所有常量都应外部化。数学常量、协议固定值和安全不变量若被随意配置，会扩大无效状态空间。先问“谁在何时有权改变”，再决定是否成为配置键。

## 3. 外部化的目标

外部化让同一构建产物进入多个环境，只替换配置来源。理想发布流程是 build once、promote same artifact；生产修正地址或凭据不需要重新编译一份未知二进制。

外部化不等于把所有行为变成字符串开关。配置需要命名、类型、默认、校验、所有者、变更流程和回滚证据。

## 4. Environment 抽象

Spring Environment 提供属性解析和 active/default profiles。它背后按顺序持有多个 PropertySource；查询键时，优先级更高且包含该键的来源获胜。

Environment 返回的是解析视图，不直接告诉业务对象每个值如何组合。业务服务应接收已绑定、已校验的配置对象，而不是到处 environment.getProperty。

## 5. PropertySource

PropertySource 是有名称的键值来源，例如默认 Map、application.properties、系统环境变量或命令行参数。MutablePropertySources 的顺序决定查询优先级。

同名键覆盖不是修改低优先级来源，而是高优先级来源遮住它。诊断时要列出来源顺序和值是否存在，不能只打开一个文件。

## 6. “最高优先级获胜”

Spring Boot 官方外部配置顺序从低到高排列，后面的来源能覆盖前面的来源。默认属性很低，config data 在其上，OS 环境变量、系统属性和命令行更高，测试专用来源又有自己的位置。

不要背一个脱离版本的口诀。升级 Boot 后应查当前官方表，并用小测试锁定项目真正依赖的几条相对关系。

## 7. 本章关注的相对顺序

工件只验证四层：默认 application.properties < profile-specific application-dev.properties < 模拟系统环境变量 < 命令行参数。越右优先级越高。

真实 Boot 还有 RandomValue、JNDI、Servlet 参数、SPRING_APPLICATION_JSON、测试注解和 Devtools 等来源。本章不把完整十五项当背诵题，但提醒它们会影响诊断。

## 8. 默认属性

默认值可以来自 SpringApplication.setDefaultProperties、基础配置文件、ConfigurationProperties 字段初值或 DefaultValue。它们不是同一个层级，也不一定都能从 Environment 查询到。

部署必须知道默认在哪里。关键安全值不应有“方便默认”，例如生产 API key 缺失应失败，不应自动变成空字符串。

## 9. application.properties

Spring Boot 会从 classpath 和外部目录的标准位置加载 application.properties 或 YAML。工件使用 properties，避免同一位置同时放 YAML 和 properties 造成格式优先级困惑。

提交到仓库的默认文件只包含非秘密、安全的开发默认：示例域名、短超时和有限重试。api-key 故意缺失，要求运行者从外部提供。

## 10. config data 位置

默认搜索包括 classpath 根、classpath /config、当前目录及其 config 位置。外部位置通常能覆盖打包内部值。spring.config.location 会替换默认位置，spring.config.additional-location 则是在默认位置之外增加。

这些键在 config data 加载早期就需要，必须通过环境、系统属性或命令行等早期来源提供。把它们放进一个尚未被找到的文件是循环依赖。

## 11. profile-specific 文件

激活 dev 后，application-dev.properties 作为 profile-specific config data 覆盖基础文件中的同名键。它应表达环境差异，例如开发端点或更短轮询，不应复制整份基础配置。

配置文件合并意味着未覆盖的键继续来自基础文件。删除 profile 文件中的键不等于把基础值清空；要根据配置合同判断缺失和显式空值。

## 12. 外部文件覆盖

生产可通过外部 config 目录覆盖打包内默认，保持 JAR 不变。文件权限、挂载路径、原子更新和回滚由部署系统管理。

不要在容器镜像构建时 sed 替换源码配置，那会产生不可追踪制品。若必须生成文件，应保存模板版本和渲染输入摘要，并阻止秘密进入构建日志。

## 13. OS 环境变量

进程启动时继承父进程提供的环境变量。Java 进程内通常把它视为启动快照，修改 shell 后已经运行的 JVM 不会自动更新。

环境变量适合容器和 CI 注入，但会被进程检查工具、崩溃采集或错误日志间接暴露。它是传递通道，不是自动加密的秘密仓库。

## 14. 环境变量命名规则

Boot 把 canonical property 转环境变量时：点变下划线、连字符删除、整体大写。例如 factorycare.api-base-url 对应 FACTORYCARE_APIBASEURL，而不是凭直觉随意加下划线。

列表索引还需要数字两侧下划线。工件用名为 test-systemEnvironment 的 SystemEnvironmentPropertySource，让 Boot 真的应用环境变量宽松绑定规则。

## 15. relaxed binding

ConfigurationProperties 支持 kebab-case、camelCase、underscore 和环境变量形式间的宽松绑定。注解 prefix 必须使用小写 kebab-case；项目文档应选 canonical kebab-case 作为唯一展示形式。

宽松绑定提升部署可用性，也可能让拼写误判更难发现。ignoreUnknownFields=false 和启动测试可把未知键转成确定失败。

## 16. Java system properties

-Dkey=value 进入 Java System properties，官方顺序中高于 OS environment。它适合 JVM 启动脚本和短期覆盖，但会出现在进程命令行、诊断输出或编排清单。

测试不能并行修改全局 System.setProperty 后忘记恢复。优先使用隔离的 ApplicationContextRunner、PropertySource 或受控 SpringApplication 参数。

## 17. 命令行参数

以 --key=value 传给 SpringApplication 的参数形成 commandLineArgs，通常覆盖文件、环境变量和系统属性。它适合一次性运维覆盖，也最容易在 shell history 和进程列表泄密。

工件只用命令行传入 test-only 占位 secret，不使用真实凭据。生产秘密优先通过平台 secret 引用、受限文件或专用 secret manager。

## 18. 先预测再启动

看到四处同名键时，先写表格：source、原始键、值、相对优先级、是否激活。预测最终值后再运行，能把“优先级理解错”和“来源没加载”分开。

只看最后值不足以诊断。若预期 env 覆盖但没生效，应先核对变量名转换、进程继承、PropertySource 名称和 profile 是否激活。

## 19. Value 的边界

Value 适合少量独立值，但多个层级字段会分散键名、默认和校验。它的宽松绑定和元数据能力也不如 ConfigurationProperties。

不要把十几个 Value 散落在服务类。把同一责任前缀聚成类型安全对象，服务只依赖这个对象。

## 20. ConfigurationProperties

ConfigurationProperties 把一个 prefix 下的层级键绑定到 POJO。FactoryCareProperties 聚合 apiBaseUrl、retry.maxAttempts、timeout 和 apiKey，并作为普通 bean 注入。

配置类只描述环境输入，不注入 repository 或业务 service。官方也建议配置属性对象只处理 Environment 数据，保持组合方向单一。

## 21. JavaBean 绑定

JavaBean 绑定使用无参构造器和 setters，适合教学观察和某些可变框架场景。字段可加 Jakarta Validation 约束，嵌套对象用 Valid 级联。

绑定完成后业务应把对象视为只读。不要在请求处理中调用 setter 改全局配置；动态配置需要专门快照和一致性协议。

## 22. 构造器绑定

单构造器类或 record 可通过构造器绑定形成不可变配置。需要 EnableConfigurationProperties 或配置属性扫描注册，并确保编译保留参数名。

不可变对象更清楚，但不能让缺失 primitive 默默变成 0。配合 DefaultValue、包装类型和校验表达真实必填/可选语义。

## 23. 类型转换

Binder 能把字符串转换为 int、boolean、Duration、DataSize、枚举、集合和嵌套对象。写 2s 比裸数字更清楚单位；网络超时不应让读者猜毫秒还是秒。

转换失败应阻止启动。不要 catch BindException 后用任意默认，因为错误部署会在流量到来后才暴露。

## 24. 嵌套配置

retry.max-attempts 属于 Retry 子对象。嵌套能把相关键放在同一边界，也便于 Valid 级联校验。

嵌套不是无限层级。过深树会难以理解覆盖和环境变量名称，应按部署责任拆分前缀或模块。

## 25. 启用属性类

EnableConfigurationProperties 可精确注册指定类型，ConfigurationPropertiesScan 则从包扫描。工件使用显式启用，避免为一个小实验扫描整个 classpath。

启用后属性对象成为 bean，绑定和校验发生在 context refresh。失败阻止 context 就绪，这正是启动前验证的目标。

## 26. 启动校验

在属性类上加 Validated，并使用 NotBlank、NotNull、Min、Max 等 Jakarta Validation 约束。classpath 必须有合规验证实现，Boot starter validation 提供组合。

校验消息可用于诊断，但自动化测试更适合检查异常类型、属性路径或稳定哨兵，不应匹配整段本地化文本。

## 27. 必填秘密

apiKey 标注 NotBlank，默认文件不提供。缺值或空白值时绑定对象不应进入可用图，context refresh 失败。不存在“先启动再等第一次调用空指针”。

测试值必须明显是假的，例如 test-only-key。任何真实 token、长度特征或供应商前缀都不能进入仓库。

## 28. 数值范围

retry.max-attempts 限制 1 到 10。0 会让系统完全不尝试，过大值会放大故障流量；合法范围属于部署合同。

范围取决于业务和外部系统，不要机械复制本章数字。生产还要配合退避、超时、幂等和总预算。

## 29. 未知键与拼写

ConfigurationProperties 默认可能忽略未知字段。教学类设置 ignoreUnknownFields=false，使 factorycare.retry.max-attempt 这种少一个 s 的键触发 UnboundConfigurationPropertiesException cause。

未知键失败能阻止配置漂移，但升级移除旧键时需要迁移计划。先部署同时识别新旧键还是一次切换，必须明确选择，不能永久容忍所有拼写。

## 30. 读取 cause 链

外层常见 ApplicationContextException、BeanCreationException 或 ConfigurationPropertiesBindException，内层可能是 BindValidationException、UnboundConfigurationPropertiesException 或转换异常。

诊断先找属性 bean 名和 prefix，再找第一处可信属性路径与拒绝原因。不要只贴最后一行“application failed to start”。

## 31. Profile 的定义

Profile 是一组命名的配置条件，能激活 profile-specific config data，也能通过 Profile 注解控制 bean 定义。它适合环境/部署能力差异，例如 dev 诊断适配器或 production 外部客户端。

Profile 不是用户角色、工单状态或 A/B 业务规则。那些会在同一运行实例内随请求变化，不应通过重启应用切 profile。

## 32. 激活 Profile

spring.profiles.active 也遵循 PropertySource 优先级。基础文件可给低优先级默认，命令行能覆盖。没有 active profile 时，default profile 参与匹配，但它不是名为 prod 的安全保证。

启动日志或健康信息可显示 active profile 名，但不得连带打印所有属性。生产部署应显式声明期望 profile，并用测试阻止空配置误启动。

## 33. profile-specific 配置合并

application-dev.properties 只覆盖 apiBaseUrl 与重试次数，timeout 仍来自基础文件，apiKey 仍从外部来源。测试逐字段断言来源效果。

复杂 list/map 的 profile 合并规则不同于简单 scalar，不能把所有结构想成逐元素拼接。进入复杂配置前查官方合并规则并写样例。

## 34. Profile 控制 bean

Profile 可以让 dev 使用 RecordingGateway、prod 使用 RealGateway，但两个实现应遵守同一端口合同。Profile 只选择基础设施装配，不复制业务决策。

若多个 profile 同时激活造成两个候选，仍需明确条件或 Qualifier。不要靠 profiles 顺序选择第一个 bean。

## 35. 不把 Profile 当业务 if

“VIP 用户走快速审批”“夜班提高优先级”属于运行时业务条件，不是 dev/prod Profile。放进 Profile 会让同一进程无法同时服务不同用户，也让规则变更依赖重启。

正确做法是领域策略、数据配置或受审计 feature flag，具体选择依赖一致性和治理要求。Profile 只解决部署级条件。

## 36. 什么是秘密

密码、API token、私钥、数据库凭据和签名密钥是秘密。普通服务地址、超时和 profile 名通常不是秘密，但仍可能是内部敏感信息。

秘密需要最小权限、静态/传输保护、审计、轮换和撤销。把值放环境变量只解决传递，不自动满足这些属性。

## 37. 秘密不能进仓库

application.properties、测试 fixture、README、示例命令、Git 历史和截图都属于可能进入仓库/工件的表面。示例只写占位符，不写可用凭据。

一旦真实秘密提交过，删除当前行不够；应立即轮换/撤销，评估历史和下游复制，再按组织流程清理历史。

## 38. 外部秘密来源

生产可使用编排平台 Secret、受限挂载文件、云 secret manager 或 Vault 等专用系统，再通过环境/文件/客户端提供给应用。选择取决于平台、轮换和审计需求。

本章不连接真实秘密系统，避免伪造安全证明。测试只验证“默认文件无秘密、缺秘密启动失败、日志摘要已脱敏”。

## 39. 脱敏输出

配置对象的 toString 不应输出 apiKey。工件只显示 apiKey=<redacted> 和非秘密字段。异常、debug 日志、Actuator env/configprops 也需要脱敏策略与访问控制。

不要仅用正则在日志末端擦除。更可靠的是源头不拼接秘密，并对结构化日志字段建立 allowlist。

## 40. Actuator 与诊断风险

Actuator 可帮助观察 Environment 和 ConfigurationProperties，但端点可能暴露键名、来源和误配置值。生产默认不公开，启用时应鉴权、限制网络并验证 sanitization。

诊断便利不能覆盖秘密边界。支持人员需要知道“哪个来源生效”，不一定需要看到完整值。

## 41. 秘密轮换

长运行进程是否能热更新秘密取决于客户端和平台。普通 Environment 启动绑定通常是快照，外部值变化不会自动替换已创建属性对象。

轮换方案要定义刷新机制、双密钥窗口、失败回滚和旧连接处理。不要假定修改 Kubernetes Secret 后所有 JVM 同时安全切换。

## 42. 测试外部配置

ApplicationContextRunner 或受控 SpringApplication 能为每个测试创建隔离 context。测试传入 property values、profile 和模拟系统环境，结束后关闭，不污染全局 System properties。

不要让测试读取开发者真实环境变量。否则本机可能通过，CI 因缺值失败，或反过来把真实 token 写进报告。

## 43. 配置漂移

配置漂移是代码支持的键、部署模板提供的键和实际运行值逐渐不一致。典型表现为旧键残留、新键缺失、拼写不同、单位变化或两个副本优先级不同。

严格未知键、启动校验、配置元数据、部署模板测试和版本化变更说明能降低漂移。只靠 Wiki 清单会过时。

## 44. 配置合同

为每个键记录 canonical name、类型、单位、默认、必填、秘密性、允许范围、覆盖来源和所有者。FactoryCare 工件的合同把 apiKey 标为 required/secret，把 timeout 标为 Duration。

合同随代码版本发布。删除或重命名键属于部署契约变更，需要影响、迁移和回滚，不应偷偷兼容所有旧拼写。

## 45. 多副本一致性

同一版本的多个实例若读取不同环境变量或文件，会表现为配置分裂。发布系统应使用不可变模板或版本化 secret 引用，并在健康/指标中暴露非敏感配置摘要。

不要暴露完整配置哈希包含秘密；可对允许公开的键生成摘要。工件不实现集群，只说明边界。

## 46. 默认文件 oracle

只提供 test-only apiKey 时，基础 application.properties 绑定默认 endpoint、retry=2 和 timeout=2s。FactoryCareProperties 校验通过，toString 中不出现 key 值。

这个测试证明 config data 和类型绑定，不证明外部目录、容器挂载或生产 secret manager。

## 47. Profile oracle

激活 dev 后，endpoint 与 retry 来自 application-dev.properties，timeout 继续来自基础文件。dev Profile 的基础设施标签 bean 可用，默认标签 bean不可用。

Profile 没有改变 WorkOrderService 的业务代码。若测试通过只是因为复制了两份 service，设计仍然失败。

## 48. 环境覆盖 oracle

模拟 SystemEnvironmentPropertySource 提供 FACTORYCARE_APIBASEURL，覆盖 dev 文件 endpoint；其 source name 以 systemEnvironment 结尾，Boot 才应用环境变量绑定规则。

若错写 FACTORYCARE_API_BASE_URL，本章合同会找不到正确键。先检查转换规则，再检查优先级。

## 49. 命令行最高 oracle

同时提供文件、模拟 env 和 --factorycare.api-base-url 参数时，命令行值获胜。测试保留四层预言表，输出只写 source=command-line 和非秘密 endpoint。

公开 verifier 不接受依赖机器环境的结果，全部输入在测试内固定。

## 50. 失败 oracles

缺 apiKey 或空白时 cause 链含绑定校验失败；retry=0 时指出 Min；未知 max-attempt 键时含未绑定属性 cause；toString 若包含 test-only-key 则测试失败。

这些故障分别证明必填、范围、漂移和泄漏边界，不能用一个 catch-all 默认值同时掩盖。

## 51. 独立构建任务

定义 FactoryCareProperties 与 Retry，使用 ConfigurationProperties、Validated、Valid、NotBlank、Min/Max 和 Duration。基础文件不含秘密，dev 文件只写差异。

写测试覆盖基础、dev、环境和命令行相对优先级，再分别制造缺秘密、拼写错和越界。每个测试关闭 context。

## 52. 修改任务

新增 maintenance-window Duration 与 enabled boolean。先更新配置合同和默认/profile 文件，再预测环境变量名，补类型转换和范围测试。

然后把旧 maintenance.minutes 迁移到新 duration 键。明确选择一次切换或短期双读，并写删除旧键的版本，不允许无限兼容。

## 53. 诊断顺序

先确认运行制品版本和 active profiles，再列 PropertySource 顺序、原始键形式与最终值。接着读取绑定异常的 prefix、属性路径、原始来源和校验原因。

秘密只报告存在/缺失与来源类型，不输出值。修复一个来源后用同一命令重跑，避免同时改文件、环境和命令行。

## 54. 120 秒复述提纲

解释 Environment 与 PropertySource、最高优先级覆盖、ConfigurationProperties 类型绑定与启动校验。说出默认文件、profile、env、CLI 的相对顺序和一个环境变量转换例子。

最后解释 Profile 只用于部署装配，不承载业务分支；秘密不进仓库、日志或默认文件，缺失必须 fail fast。

## 55. 验收清单

- 属性按 factorycare 前缀聚合并类型绑定。
- 基础/profile/env/CLI 的最终值与预测一致。
- 缺秘密、越界和未知键阻止启动。
- 默认与 profile 文件没有 apiKey。
- toString、测试输出和 verifier 不泄漏秘密值。
- Profile 只选择基础设施 bean，不复制业务规则。
- 测试不读取开发者真实环境且可离线重复。

## 56. 有意不做与兼容边界

本章不连接 Vault/云 secret manager，不启动 Web/Actuator，不实现动态刷新、feature flag、远程配置中心、Kubernetes 发布或多副本同步。只验证启动时配置快照。

没有为拼错键、空秘密、隐式 prod profile 或把秘密提交仓库保留兼容路径。旧配置迁移必须有显式期限、部署顺序和回滚；安全值不能用宽松 fallback 延续。

## 57. 一手资料

- [Spring Boot 4.1 外部配置](https://docs.spring.io/spring-boot/reference/features/external-config.html)
- [Spring Boot Profiles](https://docs.spring.io/spring-boot/reference/features/profiles.html)
- [Spring Boot 4.1 system requirements](https://docs.spring.io/spring-boot/system-requirements.html)
- [Spring Boot 4.1 managed dependencies](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)
- [Spring Boot 4.1.0 release](https://spring.io/blog/2026/06/10/spring-boot-4/)
- [Spring Framework Environment abstraction](https://docs.spring.io/spring-framework/reference/core/beans/environment.html)
