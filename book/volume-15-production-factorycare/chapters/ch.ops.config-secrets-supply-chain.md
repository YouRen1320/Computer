---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.config-secrets-supply-chain
title: 配置、密钥、依赖、SBOM 与供应链
responsibility: 分离代码、非敏感配置与密钥，校验依赖来源和 SBOM，建立轮换与泄漏响应，不把任何 secret 写入镜像、仓库或日志。
volume: '15'
order: 8
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.config-secrets-supply-chain.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.docker-production
- ch.release.ci-quality
- ch.security.untrusted-input-xss-ssrf
version_surfaces:
- ci
- git
- docker
- ubuntu-server-26.04
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“配置、密钥、依赖、SBOM 与供应链”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-config-secret
  - ops-supply-chain
  covers_topics:
  - ops.config-precedence
  - ops.secret-injection
  - ops.secret-rotation
  - ops.secret-leak-response
  - ops.lockfile-integrity
  - ops.dependency-provenance
  - ops.sbom
  - ops.vulnerability-triage
  uses_capabilities:
  - foundation.git-security
  - foundation.toolchain-env-build
  - foundation.docker-runtime
  - security.web-threat
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为多语言项目建立配置模式、运行时密钥注入、SBOM 生成、依赖来源核验和模拟 Token 泄漏轮换演练；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-config-secret
  - ops-supply-chain
  covers_topics:
  - ops.config-precedence
  - ops.secret-injection
  - ops.secret-rotation
  - ops.secret-leak-response
  - ops.lockfile-integrity
  - ops.dependency-provenance
  - ops.sbom
  - ops.vulnerability-triage
  uses_capabilities:
  - foundation.git-security
  - foundation.toolchain-env-build
  - foundation.docker-runtime
  - security.web-threat
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: secret-scan-fixtures-sbom-diff-rotation-drill
- id: diagnose
  kind: fault-diagnosis
  text: 面对“secret 进入 Git 历史/镜像层/CI 日志、生产接受未知配置、依赖来源不可追溯或仅凭 CVE 数量阻断”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-config-secret
  - ops-supply-chain
  covers_topics:
  - ops.config-precedence
  - ops.secret-injection
  - ops.secret-rotation
  - ops.secret-leak-response
  - ops.lockfile-integrity
  - ops.dependency-provenance
  - ops.sbom
  - ops.vulnerability-triage
  uses_capabilities:
  - foundation.git-security
  - foundation.toolchain-env-build
  - foundation.docker-runtime
  - security.web-threat
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 配置、密钥、依赖、SBOM 与供应链

## 1. 本章到底解决什么问题

一个应用能在开发机运行，不代表它能安全地进入生产。生产交付至少有四条彼此关联、但不能混为一谈的链路：代码决定业务行为；非敏感配置决定同一份代码在某个环境中的可调行为；密钥授予访问外部资源的权限；依赖与制品证据说明“这份程序由什么构成、从哪里来、怎样构建”。只把配置写进环境变量、只运行一次漏洞扫描，或者只生成一份 SBOM，都没有闭合这四条链路。

本章的完成标准不是背诵工具名字，而是能独立完成三个判断。第一，看到一个键值时，能判断它属于代码常量、普通配置、密钥还是发布证据。第二，看到一次疑似泄漏时，能沿 Git 历史、构建上下文、镜像层、CI 日志和运行时逐面取证，并执行撤销、轮换、重新部署和验证。第三，看到依赖告警时，不以 CVE 数量机械放行或阻断，而是把组件身份、版本、来源、可达性、可利用性、修复版本和业务暴露联系起来。

本章只使用不含敏感值的受控夹具验证策略。它不会连接真实密钥管理器，不扫描真实 Git 历史或镜像，不签名真实制品，也不宣称夹具是通过官方 schema 验证器生成的合规 SBOM。FactoryCare 的业务事实仍由 Java 服务拥有；Python 文件只是便于学习和自动验证的策略模型。

## 2. 先建立四个边界

### 2.1 代码与配置

代码表达长期稳定的业务规则，例如“只有已分配的工单可以开始维修”。配置表达部署环境可调、但不应改变业务真假的参数，例如日志级别、外部服务地址、连接池上限和功能开关默认状态。若管理员能通过配置绕过鉴权或改写订单金额，问题不是“配置很灵活”，而是业务规则越过了 Java 事实边界。

普通配置可以被运维人员读取，可以出现在部署清单中，也可以进入受控日志中的键名和非敏感枚举值。它必须有名称、类型、允许范围、默认值、是否必填、适用环境和变更责任人。没有模式的环境变量集合，本质上只是另一种无类型全局变量。

### 2.2 配置与密钥

密钥是“持有者由此获得权限”的数据，例如数据库口令、私钥、签名材料和第三方访问凭据。密钥不应该因排障方便而出现在仓库、Dockerfile 的 ARG/ENV、镜像层、构建证明、CI 输出或应用日志中。应用配置可以保存“去哪里取”和“取哪个版本”的引用，但不保存密钥值。

因此，以下是安全的抽象：

- 普通配置：数据库主机、端口、连接超时。
- 密钥引用：名称为 factorycare-database、版本为 v7。
- 密钥值：只在获授权的运行时边界短暂出现，本教材不创建、不记录、不回显。
- 审计结果：某个表面是否检测到敏感标记，只保存布尔结果和位置，不复制检测到的内容。

“已经 Base64 编码”不等于密钥已加密；“仓库是私有的”也不等于可以提交密钥。权限边界、审计范围和轮换成本仍然存在。

### 2.3 依赖清单与 SBOM

锁文件回答“包管理器下一次应解析哪些具体版本和完整性信息”。SBOM 回答“某个已产生制品里观察到哪些组件、版本、标识、关系和其他元数据”。二者应当相互核对，但不能互相替代：锁文件可能包含未打入最终制品的开发依赖，最终镜像也可能包含基础镜像操作系统包，而这些不一定出现在应用锁文件中。

SBOM 不是漏洞扫描报告。漏洞数据库随时间变化，同一份 SBOM 可以在不同日期得到不同告警。SBOM 也不是来源证明：它描述“里面有什么”，而 provenance 描述“在哪里、何时、由哪个构建者、基于哪些输入怎样产生”。签名又是另一条问题，帮助验证声明由谁签发且未被篡改。VEX 则可表达某漏洞对特定产品的可利用状态。不要把四种证据压缩成一个绿色徽章。

### 2.4 演练与生产证明

本章实验输出的是确定性模型证据：配置键是否符合模式、三个泄漏表面是否被报告、SBOM 组件是否与锁定版本一致、旧凭据状态是否为失效、新凭据状态是否为可用、发布清单是否链接了 SBOM 和 provenance。它不证明真实凭据已经撤销，不证明真实镜像无泄漏，也不证明生产注册表中的 attestation 可验证。每次报告都必须分开写“已验证”和“未验证”。

## 3. 配置模式：先定义，再读取

### 3.1 明确优先级

常见配置来源包括代码默认值、版本库中的非敏感配置文件、环境级配置、进程环境变量和命令行参数。高层覆盖低层并非天然正确；团队必须写出唯一顺序，并让程序打印“来源名称”而不是打印敏感值。一个可用的顺序是：

1. 安全且跨环境一致的代码默认值。
2. 版本控制的非敏感基础配置。
3. 环境专用的非敏感配置。
4. 部署系统注入的运行时覆盖。
5. 受控运维命令的短期覆盖。

优先级的真正风险是“同一个键在多处存在却无人知道最终值来自哪里”。解决方案不是再加一层，而是启动时生成脱敏配置摘要：键名、类型、来源、是否采用默认值和校验结果。密钥只显示引用标识与版本，绝不显示值或可逆摘要。

### 3.2 未知键应失败

生产配置中把 profile 拼成 profil，如果程序悄悄忽略，部署可能以错误默认值启动。严格模式应拒绝未知键、缺失必填键、类型错误和越界值。失败越接近启动阶段，证据越清楚；若推迟到第一次业务请求才报错，故障已经进入用户路径。

配置模式至少包含：

| 字段 | 含义 | 示例判断 |
| --- | --- | --- |
| name | 稳定键名 | LOG_LEVEL |
| type | 字符串、整数、布尔、枚举、时长 | 不能把“十秒”交给整数解析 |
| required | 无默认值时是否必须提供 | 生产数据库地址必须提供 |
| default | 安全默认值 | 本地日志级别可为 INFO |
| constraints | 范围或枚举 | 连接池上限必须为正 |
| sensitive | 是否禁止普通配置承载 | password 一律拒绝 |
| sourcePolicy | 哪些层允许覆盖 | 命令行不得改写安全策略 |

“默认值”不是减少报错的万能方法。一个静默连接到本地数据库的生产服务，比启动失败更危险。对外部资源地址、身份标识和安全策略，缺失时通常应快速失败。

### 3.3 Java 是运行时事实拥有者

在 FactoryCare，Java API 应在启动边界把外部字符串解析成类型化配置对象，再把经过校验的值传入业务组件。Controller 不应到处读取环境变量，领域对象更不应该知道部署系统。这样单元测试可以构造明确配置，启动测试可以验证绑定失败，业务规则不会被配置读取副作用污染。

如果以后使用 Spring Boot，可利用其类型化配置绑定与校验能力，但本章不把框架注解当作配置设计本身。无论框架怎样变化，严格模式、来源可解释、敏感值分离和启动失败原则都不变。

## 4. 密钥注入：值只在最小边界出现

### 4.1 构建时与运行时是两个威胁面

构建时可能需要访问私有依赖仓库；运行时可能需要访问数据库。两者必须使用不同身份、不同权限和不同生命周期。不要让生产数据库凭据进入镜像构建，也不要让构建机器人凭据长期存在于运行容器。

Docker 官方文档明确指出，构建参数和环境变量不适合传递构建密钥，因为信息可能持久化在最终镜像、镜像历史或 provenance 中；应使用 BuildKit 的 secret mount 或 SSH mount，使密钥只在相应 RUN 指令期间可见。参见 [Docker Build secrets](https://docs.docker.com/build/building/secrets/) 与 [Docker build variables](https://docs.docker.com/build/building/variables/)。

安全的 Dockerfile 设计表达“需要一个名为 maven-settings 的挂载”，而不是给出内容：

~~~dockerfile
RUN --mount=type=secret,id=maven-settings,required=true \
    ./mvnw --settings /run/secrets/maven-settings -DskipTests package
~~~

这段示意仍需在真实 CI 中验证 BuildKit、权限和日志行为。本章不会执行真实构建。

### 4.2 环境变量与文件挂载的取舍

运行时环境变量部署简单，但可能通过进程检查、错误转储、诊断页面或误打印暴露。只读文件挂载可以缩小某些暴露面，并允许应用只读取指定路径，但文件权限、挂载生命周期和更新语义必须验证。云密钥 SDK 能提供身份认证、审计和版本读取，但会引入网络可用性、缓存、限流和 SDK 依赖。

不存在“用了某产品就安全”的答案。选择时至少写清：

- 谁把引用解析成值；
- 值在哪个进程、文件描述符或内存区域出现；
- 应用启动失败时是否会回显；
- 轮换时是热加载还是重新部署；
- 旧版本何时失效；
- 审计日志由谁保管；
- 控制平面不可用时采用什么策略。

原则是权限最小、暴露时间最短、可轮换、可审计、失败可见。开发环境也不要把真实生产值复制到本地 dotenv 文件。

### 4.3 日志脱敏不是字符串替换游戏

只在日志出口用正则替换看似像 Token 的字符串不够可靠。编码、分段、异常堆栈、HTTP 客户端调试和对象序列化都可能绕过。更稳妥的顺序是：先使用允许字段清单；禁止记录请求/响应正文和认证头；把敏感类型设计为默认不可序列化；在日志管道再加防御性脱敏；最后对仓库、制品和日志做独立检测。

扫描器输出也可能成为二次泄漏源。报告应保存规则编号、位置、提交或制品摘要、是否命中和处置状态，不复制完整敏感内容。实验夹具因此只使用 secret_marker_present 布尔字段。

## 5. 轮换不是“生成一个新值”

### 5.1 正常轮换的双版本窗口

一个可回滚的轮换顺序通常是：

1. 创建新版本，但旧版本仍有效。
2. 授予新版本与旧版本等价、且不扩大的最小权限。
3. 让测试或金丝雀实例读取新引用。
4. 验证认证成功和业务 smoke，而不是只验证配置读取成功。
5. 分批把生产实例切到新版本。
6. 确认没有实例继续使用旧版本。
7. 撤销旧版本。
8. 再次验证旧版本已失败、新版本仍成功。
9. 记录时间、责任人、部署摘要和验证证据。
10. 在观察窗口结束后删除不再需要的材料。

“把配置改成 v7”只完成了第 3 至第 5 步的一部分。Oracle 必须同时看到旧凭据失效和新部署可用。若外部系统不支持并行凭据，需要预先设计停机窗口或代理层，而不是在事故时临时猜测。

### 5.2 泄漏响应顺序

发现疑似泄漏时，第一目标是切断能力，不是先清理截图或 Git 历史。建议顺序：

1. 记录发现时间、证据位置和可能权限，不传播值。
2. 立即撤销或禁用受影响凭据；如果不能立刻撤销，先缩小权限和网络范围。
3. 创建新的独立凭据，不复用旧值的变体。
4. 更新授权边界中的引用并重新部署。
5. 验证旧凭据确实失败、新路径成功。
6. 搜索 Git 历史、分支、fork、CI 日志、缓存、构建产物、镜像层、制品仓库和日志后端。
7. 清理可清理的副本并执行必要的历史重写；通知所有协作者迁移。
8. 审计泄漏窗口内的使用记录和异常访问。
9. 补上阻断规则、轮换手册和演练。
10. 保存不含敏感值的事件报告。

从 Git 删除文件并不能使已经泄漏的凭据恢复安全；撤销是第一控制。重写历史也有迁移成本，可能破坏提交哈希、开放 PR 和本地克隆，因此要给出影响、执行计划与回滚/重新克隆说明。

## 6. 锁文件、来源与完整性

### 6.1 锁定的不只是版本字符串

依赖声明可能表达一个范围，锁文件应解析到具体版本和完整性信息。CI 应使用“按锁文件安装”的命令，并在锁文件与声明不一致时失败，而不是悄悄重新解析并修改锁文件。Java、Node、Python 和 Flutter 的具体命令不同，但证据结构一致：工具版本、仓库来源、锁文件摘要、下载组件身份、完整性校验结果和最终制品摘要。

只写版本号仍可能遇到同名包、仓库镜像污染或内容被替换。可用证据包括受信任仓库的规范 URL、包坐标或 purl、校验摘要、签名/证明、发布者身份以及构建 provenance。不要在公共与内部仓库之间启用无边界的回退，以免出现 dependency confusion。

### 6.2 来源核验问题清单

对每个关键依赖至少问：

- 名称和命名空间是否明确，是否可能与公共包冲突；
- 来源仓库是否在允许清单；
- 是否使用 TLS 并验证证书；
- 锁文件是否包含完整性信息；
- 缓存是否按摘要寻址，失败时会不会回退未知来源；
- 维护者或构建者身份是否可核验；
- 依赖是否在受支持版本；
- 是否存在替代组件和移除计划；
- 许可证与使用方式是否允许；
- 构建时下载脚本是否也进入来源证据。

这些问题不是要求人工逐包审查所有传递依赖，而是帮助团队确定自动门禁、重点人工复核和例外审批。

## 7. SBOM、provenance、签名和漏洞处置

### 7.1 选择并声明格式

截至 2026-07-24，本章核对的官方页面显示 [SPDX Specification 3.0.1](https://spdx.github.io/spdx-spec/)；[CycloneDX Specification Overview](https://cyclonedx.org/specification/overview/) 列出的当前版本为 1.7。两者都能表达软件物料，但字段模型和生态不同。团队应选择与生成器、注册表、合规和漏洞平台兼容的格式，并把格式与版本写入发布证据。不要把本章的简化 JSON 当作合规文档；它只模拟组件身份、purl、摘要和依赖对账。

SBOM 质量至少包括：

- 对应哪个不可变制品摘要；
- 生成阶段和生成工具身份；
- 格式与规范版本；
- 应用、运行时、操作系统和基础镜像组件覆盖；
- 直接与传递依赖关系；
- 组件名称、版本、purl/CPE 等可匹配标识；
- 已知与未知组件的完整性声明；
- 文件摘要或组件摘要；
- 生成时间和可复现路径；
- 与发布清单、provenance 的双向链接。

组件很多不等于 SBOM 质量高；缺少制品绑定和来源信息的长列表，无法支持可靠响应。

### 7.2 构建证明

[Docker Build attestations](https://docs.docker.com/build/metadata/attestations/) 说明 BuildKit 可在构建时生成 provenance 与 SBOM attestation，并将其作为最终镜像相关元数据；具体 exporter 会影响 attestation 的存储方式。Docker 文档也提醒，某些公开仓库的 max provenance 可能记录构建参数，所以更不能把密钥放入 build args。

截至核对日，[SLSA 1.2 provenance](https://slsa.dev/spec/v1.2/provenance) 把 provenance 定义为可验证的信息，用于沿供应链追踪制品来自哪里。它不是“CI 跑过”的同义词。消费方需要验证 subject 摘要、构建者身份、输入摘要、参数和签发者，而不是只检查文件存在。

理想发布关系是：

~~~text
Git commit + lock digests + build definition
                  |
                  v
trusted builder -----> artifact digest
      |                    |
      +--> provenance      +--> SBOM
                  \        /
                   release manifest
~~~

发布清单是索引，不应复制敏感内容。环境晋级应引用同一制品摘要，不在测试和生产重新构建。

### 7.3 漏洞告警需要上下文

“有一个 CRITICAL 就阻断”看似严格，实际上会制造大量无法行动的噪声；“组件不可达所以永久忽略”同样危险。处置至少考虑：

- 组件是否真的存在于当前制品和运行路径；
- 受影响版本范围是否匹配；
- 漏洞代码是否在当前配置下可达；
- 是否已知在野利用；
- 暴露面是否面向公网或高权限数据；
- 是否有修复版本；
- 升级回归风险和预计时限；
- 是否有临时补偿控制；
- 谁批准例外，何时过期；
- 新情报出现时如何重新评估。

CVE 数量只适合做库存趋势，不适合作为唯一发布门禁。硬门禁可以聚焦“已确认存在、可达、已知利用或超过明确风险阈值且无有效例外”的项；其余进入有期限、有责任人的整改队列。例外不是关闭告警，而是保存理由、证据、期限和重新评估条件。

## 8. FactoryCare 的最小生产契约

### 8.1 配置契约

Java API 启动时读取以下类别，而不是读取本章 Python 文件：

| 类别 | 示例 | 规则 |
| --- | --- | --- |
| 普通必填配置 | 数据库主机、服务公开地址 | 缺失立即失败 |
| 普通可选配置 | 日志级别、连接池上限 | 有安全默认与范围 |
| 密钥引用 | 数据库凭据名称与版本 | 可记录引用，不记录值 |
| 业务规则 | 工单状态迁移 | 只属于 Java 领域代码 |
| 发布元数据 | commit、artifact digest、SBOM path | 只读并暴露于受控诊断面 |

启动证据可列出“DATABASE_CREDENTIAL_REF: 来源 deployment，版本 v7，校验通过”，但绝不能列出实际值。健康检查也只回答依赖是否可用，不能返回连接串或认证错误正文。

### 8.2 发布证据

一次发布至少生成或链接：

- 源提交摘要和工作流定义摘要；
- Java、Node、Python、Flutter 等实际使用的工具版本；
- 依赖声明与锁文件摘要；
- 构建者和构建运行标识；
- Java API 与前端制品摘要；
- 镜像摘要；
- SBOM 格式、路径和摘要；
- provenance 路径、subject 与验证结果；
- 漏洞处置报告及未关闭例外；
- 三个敏感表面扫描结果；
- 部署环境和配置模式版本；
- smoke、回滚和轮换演练证据。

这些证据必须能从制品反查源输入，也能从发布记录找到制品。只保存 CI 网页链接不够，因为日志保留期和权限可能变化。

## 9. 运行示例与实验

### 9.1 基础示例

进入 examples/encyclopedia/ch.ops.config-secrets-supply-chain 后运行：

~~~bash
./verify.sh
~~~

policy.py 展示四个稳定概念：低到高优先级合并、未知键失败、仅接收布尔扫描报告、SBOM 与锁定组件对账，以及基于可利用性的漏洞处置。它不读取环境变量、不接收 credential value，也不联网。测试通过只证明本地函数符合这些断言。

请故意把 environment 层加入 profil 键，预测失败位置后运行测试。第一可信证据应是配置模式报告的未知键，而不是随后某个 HTTP 请求失败。恢复后再把 SBOM 中 java-api 的版本改为 1.0.1，确认 lockfile-diff 是独立问题。

### 9.2 综合实验

进入 labs/encyclopedia/ch.ops.config-secrets-supply-chain 后运行：

~~~bash
./verify.sh
python3 supply_chain_lab.py
~~~

release-fixture.json 明确声明为受控模型，只有标识符、布尔状态和虚构摘要。正常 Oracle 必须同时满足：

1. 配置模式无未知或缺失字段。
2. git-history、image-layer、ci-log 三个表面均无敏感标记。
3. 轮换后旧身份无效、新身份有效。
4. SBOM 组件身份与 lock 一致，且每项有 purl 与摘要字段。
5. 发布清单链接制品摘要、SBOM 摘要与 provenance。
6. 可达且已知利用的演示告警阻断；不可达演示项记录并监控。

把 image-layer 的 secret_marker_present 改为 true，验证 Oracle 失败，但不要加入任何模拟密钥字符串。把 old_valid_after_cutover 改为 true，验证轮换失败。把组件版本改掉，验证 SBOM 对账失败。每次只注入一个故障，记录“阶段—首证据—修复—原命令重跑”。

### 9.3 公开练习与私有解答

exercises 下的 release_allowed 故意只按 cve_count 判断，所以至少两个测试失败，verify.sh 稳定返回 41。这是预期红，不是仓库损坏。你应在自己的学习分支补齐配置、敏感表面、轮换、SBOM 和可利用性判断，再让测试转绿。solutions-private 给出一份参考实现，它也只是策略模型，不能复制成生产密钥系统。

## 10. 故障诊断矩阵

| 现象 | 失败阶段 | 首个可信证据 | 错误修复 | 正确方向 |
| --- | --- | --- | --- | --- |
| 生产接受 profil | 配置绑定 | 未知键列表 | 再加一个同名默认值 | 严格模式并修正部署配置 |
| Git 中出现敏感内容 | 源控制/泄漏 | 命中位置与提交摘要 | 只删除当前文件 | 先撤销轮换，再清理历史和所有副本 |
| 镜像层命中 | 构建 | 层或 attestation 位置 | 在下一层 rm | 从构建输入移除并重新构建、轮换 |
| CI 日志命中 | CI 执行 | 作业、步骤、时间与规则 | 手工涂黑网页 | 撤销、清日志、关闭回显、加门禁 |
| SBOM 与锁不一致 | 制品盘点 | 组件身份差异 | 手改 SBOM | 查基础镜像/构建输入并重生成 |
| provenance 缺输入摘要 | 构建证明 | resolved input 不完整 | 上传空 JSON | 修正可信构建与验证策略 |
| CRITICAL 但不可达 | 漏洞处置 | 版本、可达性、暴露证据 | 永久忽略或机械阻断 | 有期限例外并持续重评估 |
| 旧凭据仍可用 | 轮换 | 旧身份认证仍成功 | 删除本地引用 | 在授权源撤销并复验 |

诊断时先识别阶段。配置 compile 不通过时还没有运行服务；secret 在 Git 历史命中时还没有必要先调业务接口；SBOM 对账失败时也不能通过修改测试期望值“修复”。每个阶段都有自己的首证据。

## 11. 常见误区

### 11.1 “密钥在 CI Secret 中，所以一定不会泄漏”

CI 平台可以保护静态存储，但脚本可能开启命令回显，工具可能把认证头写入 debug 日志，密钥可能进入构建参数、缓存或异常信息。平台功能只是控制的一层，必须用无值扫描报告验证实际表面。

### 11.2 “删除 Git 文件就结束”

历史、fork、缓存、构建物和本地克隆仍可能保留。更重要的是，任何已暴露凭据都必须视为不再可信。先撤销轮换，再讨论历史清理。

### 11.3 “有 SBOM 就安全”

SBOM 可能不完整、与制品未绑定、标识不可匹配或已经过期。还需要来源证明、验证策略、持续漏洞情报和处置流程。

### 11.4 “锁文件会自动防供应链攻击”

锁文件提高可复现性，但如果首次解析来自错误仓库，或者完整性字段未验证，锁住的可能正是恶意内容。来源允许清单、摘要、构建者与签名验证仍然需要。

### 11.5 “把所有告警都阻断最安全”

没有上下文的全阻断会让团队习惯绕过门禁。安全控制要让真正高风险问题更难被忽略，同时给低风险、不可立即修复的问题明确责任人与期限。

## 12. 面试与口述检查

你应能在 120 秒内回答：

“配置是可调且非敏感的运行参数，必须有类型、来源、优先级和严格模式；密钥授予权限，只保存引用，值由受控运行时注入，不能进入仓库、镜像、构建证明或日志。锁文件约束解析结果，SBOM 描述制品组成，provenance 描述构建来源，签名验证声明身份。泄漏先撤销轮换，再搜索和清理所有副本；漏洞处置结合制品身份、可达性、已知利用、暴露与修复，不按 CVE 数量机械决策。”

再给出一个越界反例：“把是否允许关闭工单做成生产环境变量”会让部署配置改写 Java 业务事实，因此不属于普通配置。

独立构建题：为一个 Java API 与 Vue 前端写配置清单、密钥引用契约、锁文件核验、SBOM/证明索引和泄漏轮换演练。提交的证据不能含任何敏感值，并必须明确哪些真实平台没有验证。

故障题：给定“CI 日志命中、旧凭据仍有效、SBOM 与锁不一致”三个现象，分别指出最早失败阶段、首个可信证据、处置顺序和重跑命令。

## 13. 官方资料与版本边界

本章在 2026-07-24 核对了以下官方一手资料：

- [Docker Build secrets](https://docs.docker.com/build/building/secrets/)：构建 secret/SSH mount 与 ARG/ENV 的边界。
- [Docker Build attestations](https://docs.docker.com/build/metadata/attestations/)：BuildKit 的 provenance、SBOM attestation 与存储边界。
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile)：RUN secret mount 和构建参数警告。
- [SPDX 3.0.1 specification](https://spdx.github.io/spdx-spec/)。
- [CycloneDX specification overview](https://cyclonedx.org/specification/overview/)：页面列出 1.7。
- [SLSA 1.2 provenance](https://slsa.dev/spec/v1.2/provenance/)：当前 approved 规范中的 provenance 定义。

本地验证使用 Python 标准库；版本以最终验证报告中的 python3 --version 为准。Docker CLI 是否安装、daemon 是否在线，都不是本实验绿灯的前提。真实 secret manager、Git/镜像/CI 扫描器、SBOM 生成器和 schema validator、签名与注册表 attestation、真实轮换和生产部署均为未验证边界，不能由本章测试结果推断。

## 14. 章节验收清单

- [ ] 我能区分业务规则、普通配置、密钥引用、密钥值和发布证据。
- [ ] 我能写出配置层顺序，并解释未知键为什么应在启动时失败。
- [ ] 我能说明 Docker build secret mount 与 ARG/ENV 的差异。
- [ ] 我能设计创建新版本、金丝雀、切换、撤销旧版本和复验的轮换。
- [ ] 我能说明泄漏响应为什么先撤销、后清理历史。
- [ ] 我能区分锁文件、SBOM、provenance、签名、扫描报告和 VEX。
- [ ] 我能把 SBOM 绑定到不可变制品摘要并与锁文件对账。
- [ ] 我不会按 CVE 数量做唯一发布判断。
- [ ] 我能运行 examples、lab 和 private solution 的绿灯。
- [ ] 我知道 public exercise 返回 41 是预期红。
- [ ] 我能把夹具验证与真实平台验证明确分开。
- [ ] 我没有在任何夹具、日志或报告中写入敏感值。
