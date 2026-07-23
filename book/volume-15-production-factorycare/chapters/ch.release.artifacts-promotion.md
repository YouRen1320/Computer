---
schema_version: 2
edition: 2026.2-draft
id: ch.release.artifacts-promotion
title: 制品、来源证明、环境晋级与发布元数据
responsibility: 一次构建并以 digest、SBOM、测试证据和来源元数据晋级同一制品，通过 Compose/Nginx smoke 验证容器到代理的交付链，不按环境重编译。
volume: '15'
order: 7
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.release.artifacts-promotion.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.nginx-tls
- ch.release.ci-quality
version_surfaces:
- ci
- git
- docker
- docker-compose
- nginx
- ubuntu-server-26.04
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“制品、来源证明、环境晋级与发布元数据”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - release-artifact-identity
  - release-environment-promotion
  covers_topics:
  - release.artifact-digest
  - release.provenance
  - release.sbom-link
  - release.build-metadata
  - release.immutable-promotion
  - release.environment-config
  - release.release-manifest
  - release.proxy-smoke
  uses_capabilities:
  - ops.container-proxy-delivery
  - foundation.docker-runtime
  - ops.linux-service-network
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 由 CI 生成带 commit、digest、SBOM 和测试链接的发布清单，将同一 Java/Vue 镜像晋级测试环境并经 Nginx/TLS smoke；独立保存可复现工件与判断结果
  covers_topic_groups:
  - release-artifact-identity
  - release-environment-promotion
  covers_topics:
  - release.artifact-digest
  - release.provenance
  - release.sbom-link
  - release.build-metadata
  - release.immutable-promotion
  - release.environment-config
  - release.release-manifest
  - release.proxy-smoke
  uses_capabilities:
  - ops.container-proxy-delivery
  - foundation.docker-runtime
  - ops.linux-service-network
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: artifact-identity-check-promotion-dry-run-proxy-end-to-end-smoke
- id: diagnose
  kind: fault-diagnosis
  text: 面对“测试与生产重新构建、只用可变 tag、发布清单缺少 commit/digest 或代理 smoke 通过却后端制品不同”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - release-artifact-identity
  - release-environment-promotion
  covers_topics:
  - release.artifact-digest
  - release.provenance
  - release.sbom-link
  - release.build-metadata
  - release.immutable-promotion
  - release.environment-config
  - release.release-manifest
  - release.proxy-smoke
  uses_capabilities:
  - ops.container-proxy-delivery
  - foundation.docker-runtime
  - ops.linux-service-network
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 制品、来源证明、环境晋级与发布元数据

CI全绿之后，还没有回答“测试过的东西是不是最终运行的东西”。如果测试环境构建一次、生产环境再构建一次，即使源码提交相同，也可能因为基础镜像、依赖仓库、时间、构建器或脚本漂移产生不同字节。可靠交付的原则是：一次构建，得到不可变身份；质量证据绑定该身份；随后把同一制品晋级到各环境，只改变环境配置，不重新编译。

本章把Java API镜像、Vue静态站点镜像、Git commit、内容digest、SBOM、来源证明、质量门禁和代理smoke组成发布清单。Docker、Compose、Nginx和GitHub attestations是当前版本表面；稳定核心是内容寻址、来源可追溯、构建与部署分离、环境不重建、验证对象与运行对象一致。

本章不负责密钥管理的全部细节，不教授流水线基础，也不展开数据库迁移和回滚策略。它负责从“门禁通过”到“候选环境解析到同一制品并通过TLS/静态/API smoke”的交付链。

## 1. 什么是发布制品

制品是构建过程产生、可以存储、验证和部署的不可变输出。Java项目可能产生JAR和容器镜像，Vue产生静态文件包或Nginx镜像，Python服务产生wheel、容器或模型包。源码仓库不是运行制品，构建目录也不是稳定交付接口；部署时从开发机现编译，会失去CI环境和证据链。

一个制品需要三个层次身份。逻辑名称告诉人它是什么，如 `factorycare-api`；版本或tag提供人类可读指针，如 `2026.07.24.1`；digest由内容计算，标识确切字节或OCI manifest。名称和tag能移动，digest才适合证明“同一个”。

### 1.1 文件摘要与OCI digest

普通文件可以计算SHA-256：

```bash
sha256sum factorycare-api.jar
```

macOS工具名称可能不同，发布环境应固定命令并保存算法。OCI镜像digest通常标识manifest或index，不等于某个导出tar的文件hash，也不等于Image ID。多架构tag可能解析到image index，再按平台选择具体manifest；发布清单要说明记录的是index还是平台manifest，并在目标环境核对。

OCI分发规范把tag定义为可读的manifest指针，一个manifest可有零个或多个tag；digest则是内容的唯一标识。部署 `image:stable` 时，今天和明天可能解析不同内容。生产候选应使用完全限定镜像名加digest，tag只作为辅助显示。

## 2. 一次构建、逐环境晋级

“晋级”不是复制源码到下一环境重新构建，而是让下一环境引用已经通过前一门禁的同一digest。流程可以是：CI构建API与Web镜像；扫描、测试并生成SBOM/来源证明；推送registry；测试环境以digest部署并smoke；批准后生产候选引用相同digest；部署前再次解析与验证。

不同环境需要不同数据库地址、域名、限额、日志级别和密钥。这些属于运行配置，应在部署时注入，而不是写进环境专用镜像。若前端在构建时把API地址编译进静态bundle，需要设计运行时配置文件、相对路径或为每个配置重新建立独立制品和完整门禁；不能一边宣称“同一制品”，一边暗中重新build。

### 2.1 构建一次不等于永不重建

发现基础镜像漏洞或依赖更新时，需要从源码重新构建新制品，产生新digest并重新走门禁。这是新的发布候选，不是修改旧digest。内容寻址的价值是旧身份不变，便于知道运行的究竟是哪一版；不是阻止安全更新。

可重复构建尝试让相同输入产生相同输出，但实际工具链可能包含时间戳等非确定因素。即使尚未实现字节级复现，一次构建晋级仍能保证测试和生产使用同一已生成对象。可重复性是更强的供应链能力，不能用“我们大概能再构建”替代实际digest一致。

## 3. 发布清单是交付合同

发布清单把散落证据绑定为一个候选。建议字段包括：schema版本、release ID、完整Git commit、仓库、工作流run、触发事件、构建时间、每个制品的registry名称和digest、SBOM身份、来源证明位置、必需门禁及结论、环境解析结果、smoke结果、审批、发布时间和回滚目标。

一个受控示例：

```json
{
  "release_id": "factorycare-2026.07.24.1",
  "commit": "<40-hex-commit>",
  "quality_gates": {
    "java-test": "success",
    "web-test": "success",
    "security": "success"
  },
  "artifacts": {
    "java-api": {
      "name": "registry.example/factorycare-api",
      "digest": "sha256:<64-hex>",
      "sbom_digest": "sha256:<64-hex>",
      "provenance_uri": "..."
    }
  }
}
```

占位符不能进入真实发布。schema要做运行时校验，缺字段应失败关闭。清单本身也可计算摘要和签名，存入受控仓库或release记录。手工聊天消息“用1.2版本”不是发布清单，因为没有不可变身份、来源和门禁。

### 3.1 commit与digest都需要

commit回答“源自哪份代码”，digest回答“部署哪份内容”。一个commit可以因参数、平台和基础镜像产生多个制品；一个制品也可能包含生成代码和依赖，不由commit单独描述。两者互补，不能只记录其一。

API应暴露去敏版本端点或在响应头/日志中报告release ID、commit和artifact digest的短显示，smoke据此确认代理后真正到达的后端。显示值来自构建注入的只读元数据，不能由可变环境变量随意伪造；完整身份仍以发布清单和registry为准。

## 4. 来源证明（provenance）

来源证明是关于“谁在什么环境，依据什么源码和构建定义，产生了哪个subject”的签名声明。它把制品digest连接到仓库、commit和workflow。证明不是制品安全证书：受信工作流也可能构建有漏洞代码；它提供可验证来源，消费方仍需制定允许的仓库、分支、工作流和身份政策。

GitHub当前官方artifact attestations基于Sigstore相关机制，可为二进制或容器镜像建立声明。官方文档明确：生成attestation本身没有安全收益，消费侧必须验证；私有仓库可用性还与GitHub套餐有关。采用前应核对当前计划、权限和存储语义，不能把本章静态URI当真实签名。

### 4.1 subject必须是同一digest

生成证明时subject digest必须来自实际构建输出。不能先对tag签名，再让tag移动；不能对一个本地文件hash签名却部署另一个registry manifest。工作流应从push/build step读取规范digest，生成证明后由独立verify步骤按策略验证，再写入清单。

验证策略至少限制：预期仓库/所有者、workflow身份、ref或环境、subject名称和digest。仅验证密码学签名有效，而不检查签名者和构建来源，仍可能接受攻击者合法签名的恶意制品。

### 4.2 来源证明与可重现性

provenance说明构建发生过什么，可重现构建则让另一受控构建验证输出字节。二者不同。高保障场景可组合：先验证来源，再用独立构建比较digest。普通项目可先完成一次构建晋级、完整清单和消费侧验证，随后提升隔离与复现等级。

## 5. SBOM：制品里有什么

软件物料清单（SBOM）列出制品包含的组件、版本、包标识、许可证和依赖关系。它帮助漏洞响应回答“哪些运行制品包含某组件”，但不等同于漏洞扫描，也不证明列举完整。生成SBOM的对象必须与部署digest绑定；只扫描源码依赖清单可能遗漏基础镜像OS包和构建复制内容。

Java JAR、Node静态构建和容器层有不同生态。容器SBOM可以合并OS与应用包，但需要记录工具、格式、版本和生成时机。一个镜像更新基础层后，即使应用commit不变，SBOM与digest都应改变。发布清单保存SBOM文件digest或OCI关联subject，防止拿错报告。

### 5.1 SBOM不是密钥清单

SBOM应描述组件，不应包含Token、私有registry密码和用户数据。生成工具需要读取构建内容，但输出仍要审查敏感路径。公开制品的SBOM可以增强透明度，内部制品则按访问政策共享。

漏洞数据库会更新，因此“构建时扫描无高危”不是永久事实。保留SBOM后可在新漏洞出现时重扫已部署制品，不需重建才能知道影响面。真正修复仍要产生新制品并重新门禁。

## 6. build metadata与时间线

制品元数据应包含commit、dirty状态、构建run、工具链、构建平台、创建时间和版本。dirty源码不应进入正式CI；本地实验若构建dirty制品必须明确标记。时间统一UTC或带时区，避免发布、证明和日志难以关联。

生成版本时不要让构建脚本依赖未声明的当前分支名或本地Git标签。CI在detached HEAD、merge commit或浅克隆中的行为不同。使用平台提供且经核验的commit，并把“源commit”和“被测试的merge commit”分别记录。

### 6.1 元数据不能决定业务事实

release ID用于运维追踪，不应改变工单状态机。Java API拥有业务事实；Vue显示版本；Python派生服务记录自己的制品身份。各服务可独立发布，但端到端FactoryCare清单要记录兼容组合，避免前端smoke命中新API而后台某节点仍旧。

## 7. 环境配置与不可变制品

同一镜像进入测试和生产时，差异应来自外部配置：数据库连接引用、域名、资源限额、日志出口、feature flag和secret。配置也要版本化或有不可变修订身份，发布清单记录其引用但不记录secret值。这样可以区分“制品变了”和“配置变了”。

启动时校验配置schema，未知或缺失字段失败关闭。不要把默认开发数据库作为生产缺失配置的fallback。环境变量全是字符串，布尔、数字、URL和列表要严格解析。动态feature flag改变运行行为，也应进入事故时间线和审计。

### 7.1 前端运行时配置

Vue构建常把 `VITE_*` 值编译进bundle，导致每环境重建。可选择同域相对API路径由Nginx代理，或部署时生成独立小型runtime config并让主bundle读取。无论哪种方案，都要防止config脚本注入、设置正确缓存策略并在smoke中验证。主静态bundle digest应在环境间一致。

## 8. registry、tag与晋级动作

registry保存blob和manifest。tag方便人和工具发现，如 `candidate`、`stable`，但晋级的实质是让环境清单引用已验证digest，或把新tag指向同一digest后再解析核对。不要pull tag后仅记录tag；保存解析digest。

跨registry复制时，应使用保留manifest和digest语义的工具，并验证目标digest。若目标registry重写manifest或媒体类型，digest可能变化，此时不能口头称同一制品；需要理解转换并建立等价证据，或采用不重写路径。最简单可靠的是所有环境从同一受控registry按digest拉取。

### 8.1 多架构镜像

Apple Silicon开发机和Linux amd64服务器可能选择不同平台manifest。一个tag的index digest相同，但每个平台运行不同子manifest。测试环境必须包含生产目标平台，发布清单记录index和目标平台digest。只在arm64笔记本run成功不能证明amd64生产镜像。

## 9. Compose与Nginx smoke

测试环境通过Compose启动Java API、Web/Nginx和必要依赖。Compose文件引用digest，不使用latest；环境配置从测试作用域注入；健康检查反映就绪而非仅进程存在。Nginx以TLS或受控测试证书提供入口，代理API路径并服务静态资源。

端到端smoke至少验证三类：TLS握手和主机名/链；静态首页及一个带hash资产可获取且内容/缓存头合理；API健康/版本端点通过代理返回预期release commit和digest。直接访问容器端口的成功只能作为下层诊断，不能替代代理smoke。

### 9.1 smoke必须验证身份

`GET /health` 返回200却没有版本字段，可能命中旧容器、错误上游或占位服务。smoke要断言响应中的release元数据与清单一致；代理日志关联请求ID；Compose实际解析镜像digest与清单一致。静态站点也可用manifest或资产hash确认版本。

TLS smoke不能使用 `-k`。测试CA应由客户端明确信任，主机名匹配。若测试只验证明文HTTP，它没有覆盖生产TLS链路，必须标为未验证。

## 10. promotion dry-run与审批

真正变更环境前先执行dry-run：读取发布清单，验证schema、commit、门禁、attestation和SBOM关联；解析目标环境当前/候选digest；展示将变化的配置和制品；检查权限、容量和回滚对象。dry-run不写环境，但输出可审查计划。

审批者应看到风险而不是只点按钮：变更范围、从哪个digest到哪个digest、测试证据、已知问题、数据库兼容性、回滚路径。审批身份和时间写入发布记录。审批后若清单或digest改变，旧审批失效。

### 10.1 晋级状态机

可以把候选状态建模为 built→gated→test-deployed→test-verified→approved→production-candidate。每一步只接受前一步的同一manifest ID，失败记录原因而不篡改已生成制品。状态机属于发布系统，不是FactoryCare工单状态；不要复用业务表临时保存。

并发发布需要环境锁。两个候选同时晋级会让smoke对象与最终对象错位。锁持有者、超时和取消语义需记录；旧候选测试完成后也不能覆盖已批准的新候选。

## 11. 四类故障注入

### 11.1 测试与生产重新构建

测试digest为A，生产阶段执行build得到B。即使commit相同，首个可信证据是环境解析digest不一致。修复流水线让生产只接受清单中的A；若必须重建B，则它成为新候选并重跑全部门禁。不能把B重新打同tag假装一致。

### 11.2 只使用可变tag

清单写 `factorycare-api:1.2`，没有digest。tag可能被覆盖，无法证明运行内容。首证据是清单schema允许缺digest或环境只报告tag。修复为digest必填、解析后比较；tag保留显示。注入移动tag后，门禁应检测不同digest并停止。

### 11.3 清单缺commit/digest

缺commit无法回源，缺digest无法绑定制品。解析器应在部署前失败，不允许从tag或当前HEAD猜测。修复生成步骤后，还要校验字段格式、来源和相互关系，而不是填合成值。

### 11.4 代理smoke通过但后端不同

入口 `/health` 返回200，版本字段却是旧commit；或多节点只有部分旧。首证据是smoke响应身份与清单不符。修复服务选择、Compose引用或滚动状态后，重复多次请求并关联节点。只看一次200不足以证明集群一致。

## 12. 回滚与前向修复的边界

本章只要求发布清单记录上一已知良好digest，真正数据库兼容与expand-contract在部署迁移章节处理。容器回到旧digest不保证数据库能回退；新代码若已写入旧代码不懂的数据，盲目回滚更危险。

但不可变制品让回滚至少不需要现场重建。旧digest、配置修订和证据仍可获取；切换后再smoke确认身份。若registry保留策略删除旧blob，纸面回滚计划无效，因此需要验证保留与拉取。

## 13. 本章可运行资产

示例用Python校验完整commit、artifact/SBOM sha256、全部质量门禁和provenance URI，并比较环境digest。实验加载合成JSON清单，验证测试与生产候选解析同一API/Web digest，TLS/静态/API smoke为pass且API报告commit一致。公开练习故意比较tag；私有解答比较严格digest。

夹具中的重复十六进制和 `fixture://` URI只用于结构测试，不是存在于Git、registry、SBOM系统或签名服务的真实身份。绿灯不证明镜像已构建/推送，不证明attestation签名、SBOM完整、Compose/Nginx/TLS或云环境。完整实验必须保存真实commit、registry digest、证明验证输出、SBOM摘要、Compose解析、代理请求与响应身份。

## 14. FactoryCare交付清单

Java API和Vue Web各有独立digest；Python服务若随系统发布也单列，不与Java共享业务所有权。发布清单记录兼容组合。客户端不会写服务器制品；Java继续拥有工单、设备、权限和状态机事实。Nginx只负责入口/静态/代理，不能伪造API版本字段。

完成判据：构建、测试、测试环境和生产候选解析到同一digest；清单能追溯commit、workflow、门禁、SBOM和来源证明；不同环境只替换声明配置；TLS、静态和API smoke都通过并报告清单身份；任一不一致立即阻止晋级并保留证据。

## 15. 已验证与未验证边界

当前已在本机执行Python标准库验证：示例、dry-run清单和私有解答应绿，公开tag练习应稳定红。未访问Docker daemon、registry、GitHub attestations、Compose、Nginx、TLS或真实环境。所有外部交付结论仍未验证。

后续真实实验只能在获得仓库、registry和测试环境授权后运行，不自动推送、打tag或部署。运行时记录工具版本和日期；若平台功能或套餐不支持attestation，清单明确使用的替代机制和局限，不能伪造官方证明。

## 16. 清单演进、保留与审计

发布清单本身也有schema版本。增加可选字段通常可以向后兼容，删除或改变字段语义则需要迁移读取器。部署工具必须拒绝未知的破坏性schema，而不是忽略关键身份字段继续发布。每个解析器用黄金清单、缺字段、未知字段、错误digest和旧schema建立测试；转换后保留原始清单和迁移记录，不能覆盖历史证据。

registry垃圾回收与保留策略会直接影响回滚。tag被移动后，未被tag引用的旧manifest和blob可能进入清理范围；清单里有digest却拉不到制品，回滚仍不可执行。为已批准和仍在支持期的release建立保留规则，定期从隔离环境按digest实际拉取并校验，而不是只检查registry UI中有一行记录。SBOM、attestation和测试artifact的保留期也要覆盖事故调查窗口。

审计问题应能在有限时间回答：当前生产每个服务解析到哪个digest；它来自哪个commit和workflow；哪些门禁批准；哪个SBOM和来源证明绑定它；何时由谁晋级；smoke验证了哪个入口和哪个后端身份；上一已知良好制品是否仍可获取。若答案依赖某位工程师聊天记录，交付链还没有形成系统证据。

### 16.1 代理与多实例一致性

多实例部署中，一次smoke可能只命中某个新节点。应让版本响应包含实例或制品身份，在受控次数内覆盖后端，或从编排器读取每个实例的解析digest再与外部smoke结合。负载均衡会话粘滞、缓存和连接复用都可能让重复请求仍命中同一节点；因此“请求十次”不是普遍充分判据，需要按拓扑设计oracle。

静态资源还会经过浏览器/CDN缓存。HTML可能已更新，旧JavaScript仍缓存；也可能入口返回旧HTML却API已升级。推荐内容hash文件名配长期不可变缓存，HTML和运行时配置使用可重新验证策略。smoke断言HTML引用的资产hash属于发布清单，并用无缓存对照确认源站，再单独验证缓存策略。不要用清空所有用户缓存作为常规发布步骤。

### 16.2 诊断回答模板

面对晋级异常，先写期望manifest ID及每个artifact digest；再列CI构建输出、registry解析、测试环境解析、候选环境解析和API实际报告值。最早出现差异的位置就是优先调查点。修复后从该位置开始重跑，并完成TLS、静态和API整链smoke。若只重新打tag或修改清单使它“看起来一致”，没有改变运行对象，属于篡改证据而非修复。

两分钟复述时，你应能说明tag为何不是身份、commit为何不能替代digest、SBOM为何不等于无漏洞、attestation为何必须消费侧验证、环境配置为何不能触发重建，并给出“测试与生产分别build”这个越界反例。独立实验要让同tag不同digest稳定失败、不同tag同digest通过，并保存清单和dry-run输出。

## 17. 官方资料入口

- GitHub artifact attestations概念：<https://docs.github.com/en/actions/concepts/security/artifact-attestations>
- GitHub使用attestations建立来源：<https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations>
- OCI Image Manifest规范：<https://github.com/opencontainers/image-spec/blob/main/manifest.md>
- OCI Distribution规范：<https://github.com/opencontainers/distribution-spec/blob/main/spec.md>
- Docker构建最佳实践：<https://docs.docker.com/build/building/best-practices/>

来源证明、SBOM格式、registry referrers和平台权限都在演进。采用时以当前官方文档和实际工具输出为准，保存核验日期与版本；不要把本章合成清单、占位digest或静态绿灯当生产交付证据。
