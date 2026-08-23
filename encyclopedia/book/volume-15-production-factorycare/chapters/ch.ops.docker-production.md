---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.docker-production
title: 镜像层、容器、卷、网络与运行时边界
responsibility: 把应用构建为最小、非 root、不可变且可复现的容器镜像，明确进程、文件系统、卷和网络边界，不编排多服务。
volume: '15'
order: 3
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.docker-production.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.network-diagnostics
- ch.foundations.docker-basics
version_surfaces:
- linux
- ubuntu-server-26.04
- docker
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“镜像层、容器、卷、网络与运行时边界”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-container-image
  - ops-container-runtime
  covers_topics:
  - ops.dockerfile-stage
  - ops.image-layer-cache
  - ops.image-digest
  - ops.nonroot-image
  - ops.container-process
  - ops.container-filesystem
  - ops.volume-boundary
  - ops.container-network
  uses_capabilities:
  - foundation.docker-runtime
  - ops.linux-service-network
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为 Java API 与 Vue 静态构建各制作多阶段、非 root、固定基础镜像 digest 的 Dockerfile，并验证信号、只读文件系统和卷；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-container-image
  - ops-container-runtime
  covers_topics:
  - ops.dockerfile-stage
  - ops.image-layer-cache
  - ops.image-digest
  - ops.nonroot-image
  - ops.container-process
  - ops.container-filesystem
  - ops.volume-boundary
  - ops.container-network
  uses_capabilities:
  - foundation.docker-runtime
  - ops.linux-service-network
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: image-build-audit-signal-test-readonly-filesystem-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“latest 基础镜像漂移、把密钥复制进层、PID 1 不转发信号或应用依赖容器可写层保存数据”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-container-image
  - ops-container-runtime
  covers_topics:
  - ops.dockerfile-stage
  - ops.image-layer-cache
  - ops.image-digest
  - ops.nonroot-image
  - ops.container-process
  - ops.container-filesystem
  - ops.volume-boundary
  - ops.container-network
  uses_capabilities:
  - foundation.docker-runtime
  - ops.linux-service-network
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 镜像层、容器、卷、网络与运行时边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《DNS、端口、代理、TCP、TLS 与网络诊断》](ch.ops.network-diagnostics.md)：生产容器的监听地址、容器网络、DNS 和端口故障需要已验证的分层网络诊断能力。
- [《镜像、容器、卷、端口与容器网络》](../../volume-00-computer-foundations/chapters/ch.foundations.docker-basics.md)：生产镜像建立在已验证的镜像、容器、卷和端口基础操作上。
<!-- END GENERATED LEARNING PREREQUISITES -->

容器不是轻量虚拟机，也不是“把项目文件压缩一下”。镜像是按内容组织的只读文件系统与运行配置；容器是在主机内核上运行的隔离进程，加上一层临时可写层、网络命名空间和显式挂载。生产化的目标是让构建输入可追溯、最终镜像最小、进程非root、文件系统尽量不可变、数据离开容器临时层、网络暴露最少，并为信号与健康建立真实证据。

本章只讨论单个Java API镜像和Vue静态制品镜像的边界，不编排多服务。Docker官方当前文档用于核对多阶段构建、digest、构建密钥、USER、挂载和网络事实。示例中的64位重复digest是合成教学值，不能pull；本机只有Docker CLI 28.4.0，Docker daemon未运行，所以本章资产只完成静态源码审计，不声称构建过镜像、启动过容器或验证过PID 1与只读根。

## 1. 镜像、容器与主机

镜像由清单、配置和文件系统层组成。Dockerfile每条可能改变文件系统的指令会形成可复用构建结果。镜像内容寻址意味着层可共享，但“有digest”不等于安全；digest只固定字节身份，仍要核对来源、漏洞、许可证和构建证明。

容器以某个镜像为初始根文件系统并启动一个主进程。它共享主机内核，不自带独立内核。命名空间提供进程、网络等视图隔离，cgroup限制资源；隔离强度仍取决于主机、daemon、权限和内核配置。

容器默认可写层是短暂的。删除容器会删除这一层的数据。日志、上传文件和数据库若只写这里，重建后丢失。应用代码反而应随镜像不可变，不靠进入容器手工修文件。

Docker daemon通常拥有高权限。能控制daemon的主体往往能获得主机重大能力，因此Docker socket不能随意挂入应用容器，开发工具权限也需治理。

## 2. 构建上下文是第一道边界

docker build最后的路径定义构建上下文。Dockerfile中的COPY只能看到上下文允许的内容，但如果把仓库根整个送入，.env、私钥、测试导出和Git历史可能先进入builder，再被误复制进层。

.dockerignore减少发送内容与缓存无关变化。它不是密钥管理系统，也不能补救已在Dockerfile中COPY的秘密。审查应同时看实际上下文文件清单、ignore规则、COPY范围和构建日志。

不要用ARG或ENV传构建密钥。Docker官方Build secrets文档指出构建参数和环境变量不适合秘密，因为会持久化到最终镜像或元数据；应使用BuildKit secret/SSH mount，仅在对应RUN期间可见。即便使用secret mount，构建脚本也不能把值复制到输出。

最强策略是构建根本不需要生产秘密。Maven私有仓库令牌等确需凭证时用短期、只读、最小范围令牌，并扫描最终层、history和制品。

## 3. 多阶段构建

多阶段Dockerfile包含多个FROM。builder阶段拥有JDK、Maven、Node和编译工具；runtime阶段只复制jar或dist等产物。Docker官方说明每个FROM开始新阶段，可选择性从前一阶段复制，从而把构建工具留在最终镜像之外。

Java示例先复制mvnw、pom与wrapper获取依赖，再复制src构建；这样源码变化不必让依赖层全部失效。最终阶段使用JRE而非JDK，在/app放单一jar，以明确UID运行。

Vue示例用Node阶段执行锁文件安装与构建，再把dist复制到Nginx或静态服务器镜像。生产镜像不包含node_modules、源码、包管理器缓存和开发服务器。Vite dev server不是生产静态服务器。

多阶段不是自动安全。COPY --from=build / /会把整个builder搬回；使用未固定builder基础镜像仍会漂移；构建脚本可能把密钥写进jar或source map。最终镜像仍需清单与扫描。

## 4. 层与缓存

BuildKit根据指令、依赖文件和上下文内容决定缓存复用。把稳定依赖描述先COPY、变化快的源码后COPY，能提高命中率。RUN中下载依赖的结果也要由锁文件与校验约束，否则缓存只是重复旧的不确定结果。

缓存不是正确性证明。锁文件变化必须使相关层失效；远程包索引变化不能被“以前成功”掩盖。CI要保存构建器、平台、源码commit、锁文件hash和输出digest。

同一Dockerfile在不同平台、时间或上游仓库下可能产生不同镜像。若目标需要位级复现，还要控制基础镜像、依赖、时间戳、构建参数和平台。通常先实现可追溯，再逐步提高可复现级别。

清理缓存与拉取新基础镜像是不同操作。Docker官方说明--no-cache重新执行层，但不会自动拉新base；--pull检查更新base。若已固定digest，更新由显式PR改变digest完成，获得审计轨迹。

## 5. tag与digest

tag是可读且通常可变的引用；latest没有“最新且安全”的特殊保证。仓库维护者可以让同一tag指向不同manifest。只写FROM image:latest无法回答三个月前究竟用了什么。

digest是内容身份，例如image:version@sha256:...。官方最佳实践指出固定digest可保证构建解析到相同镜像，即使tag后来变化。代价是不会自动获得安全更新，所以需要机器人或定期PR审查新digest，而不是永不更新。

发布时同时保留语义tag与digest：tag方便人和策略理解，digest用于部署与证据。运行中的容器应能追溯到镜像digest、源码commit、SBOM和测试记录。

本章fixture中的全1/全2digest仅测试格式。它们不是仓库解析结果，不能作为“镜像已固定”的真实供应链证据。真实证据必须由registry/构建输出取得。

## 6. 最小运行时与非root

最终镜像只含运行必需文件。较小通常减少下载与攻击面，但不能只比较MB；缺少CA证书、时区或字体会造成功能故障，保留的组件也必须更新。

Dockerfile用USER切换运行用户。官方最佳实践建议无特权服务使用USER，并在需要时显式UID/GID。固定数字UID方便卷权限，但要协调宿主与平台策略；仅写用户名仍需知道镜像内映射。

非root不是万能。多余Linux capabilities、可写敏感挂载、宿主Docker socket或特权模式仍可造成严重风险。运行时还应drop不需要的capability、no-new-privileges、只读根和资源限制。

低端口监听不应成为root理由。容器可监听8080，由代理或端口映射提供443。Java API只需要应用端口；Nginx可使用非特权8443或配置恰当能力。

## 7. ENTRYPOINT、CMD与PID 1

容器的主进程通常成为PID 1。Docker停止容器时向主进程发送停止信号，等待宽限期后再强制终止。应用必须接收TERM、停止接流量、完成有限清理并退出。

ENTRYPOINT/CMD的JSON exec形式直接启动目标进程；shell形式通常先启动/bin/sh，可能影响信号传递和参数。Java使用ENTRYPOINT ["java","-jar","/app/app.jar"]比字符串形式更清楚。

若确需启动脚本，最后用exec替换shell，并转发信号。应用产生子进程时还需回收僵尸；Docker的--init可插入小型init，但是否需要应通过真实进程树与信号测试决定。

STOPSIGNAL声明期望信号，却不能证明程序正确处理。真实验证应启动容器、发docker stop、记录主进程收到信号、readiness先失败、在宽限期内退出且无KILL。静态看到STOPSIGNAL只能证明意图。

## 8. 不可变根文件系统

镜像层只读，但容器默认增加可写层。运行时--read-only可把根文件系统设为只读，迫使应用显式声明可写路径。临时文件可用tmpfs，持久数据用volume，配置和秘密用只读挂载。

Java常需/tmp，Nginx需cache与pid目录。不要因此放弃只读根；为精确目录提供tmpfs并给正确UID权限。启动时若尝试写/app，测试应失败并修代码或路径。

只读根降低被篡改和持久化风险，也验证“容器可替换”设计。它不阻止对显式可写volume的破坏，也不替代应用授权、备份与主机安全。

本章daemon离线，未实际运行--read-only。fixture只检查Dockerfile没有明显依赖写层，并在教材中给出真实测试计划，不能将静态PASS改名为readonly smoke。

## 9. 卷、bind mount与tmpfs

Docker官方Running containers文档说明容器可写层随容器删除，而volume用于持久数据；挂载还包括bind mount。三者责任不同：volume由Docker管理生命周期，bind把特定宿主路径暴露给容器，tmpfs只在内存/容器生命周期内。

数据库数据放命名volume，业务上传可放对象存储或受管理volume，临时解压放tmpfs。应用jar、Vue dist不放开发bind mount覆盖，否则生产制品身份失真。

挂载要声明读写、目标路径与所有权。配置与证书通常只读；数据库数据可写。将整个宿主根目录或Docker socket挂入是高风险能力扩张。

卷不是备份。删除、逻辑损坏和勒索会同步影响卷。必须有独立备份、恢复演练、加密和保留策略；后续章节处理备份恢复。

## 10. 容器网络

容器默认可出站；连接自定义网络的容器可按容器/服务名进行DNS通信。IP可能在重建时变化，因此不要持久化容器IP。单容器章节只建立端口与监听心智模型，多服务隔离留给Compose。

EXPOSE是镜像元数据，不自动向宿主发布端口。docker run -p才创建发布映射。应用在容器内只监听127.0.0.1时，映射可能仍无法从容器外访问；通常服务监听0.0.0.0的应用端口，再由网络策略限制范围。

不要给数据库默认-p 5432。只有入口代理发布宿主端口，API与数据库留在内部网络。出站也应按平台能力限制，尤其防止SSRF访问元数据服务与内网。

DNS、TCP、TLS和HTTP故障仍按前章分层诊断。重启容器不能修正错误host名、只监听loopback或防火墙策略。

## 11. Java API镜像合同

输入包括源码commit、Maven wrapper、pom与锁定/校验的依赖、固定builder/runtime digest和构建平台。builder运行测试与package；runtime只复制已验证jar。

运行用户为固定非0 UID，工作目录只读，/tmp为tmpfs。配置从运行环境注入，密钥不进jar、ENV或layer。Spring Boot监听8080，暴露liveness/readiness端点，但健康的语义由应用真实依赖策略决定。

Java进程作为PID1直接启动，接收TERM并优雅关闭。数据库事实、工单状态机与授权仍在Java内部；容器化只改变交付边界，不把业务规则搬到Dockerfile。

真实验收需记录image inspect用户、RepoDigests、history、SBOM/扫描、只读启动、卷写入、health和stop时间。本章静态夹具没有这些actual字段。

## 12. Vue静态镜像合同

Node builder使用固定基础digest与锁文件的冻结安装模式，执行单元测试和构建。runtime只包含dist与服务器配置。不要将.env生产密钥编进Vite，因为浏览器下载的JS对用户可见。

前端“环境变量”常在构建时替换，测试/生产若分别重建会产生不同制品。更稳的发布策略是同一静态制品通过运行时公开配置或后端相对URL适配环境，且公开配置不含秘密。

哈希命名assets可长期immutable缓存；index.html短缓存/重新验证以便引用新hash。SPA fallback与API代理在Nginx章节处理，不能把API 404改成index.html。

静态镜像也应非root、只读根、明确tmpfs与端口。若使用官方Nginx镜像，检查实际用户、配置目录和写路径，而不是假设镜像天然满足。

## 13. 健康与生命周期

Dockerfile HEALTHCHECK可声明检查，但单机docker run是否消费它取决于上层操作。健康检查应验证服务能处理目标请求，不能只看进程存在；同时要轻量、有超时、start_period与合理重试。

liveness失败常触发重启，readiness失败只应停止接流量。若用一个深度检查同时承担两者，数据库短暂慢可能造成重启风暴。Java Actuator端点需要按平台合同配置。

restart policy不能修永久配置错误。凭证错误、迁移失败或端口冲突若无限重启，只会淹没首个日志并增加负载。先保存首次失败证据。

生命周期验收包括启动、就绪、停止、异常退出和重建后数据。每个阶段有明确超时与Oracle，不能只看docker ps显示Up。

## 14. 静态审计与真实验证分层

T1静态审计检查Dockerfile多阶段、FROM digest、最终USER、JSON ENTRYPOINT、COPY范围和上下文秘密名称。它快、确定，但看不到真实层、用户解析、信号和文件权限。

T2构建验证实际执行docker build，保存输出digest、build metadata和扫描。T3运行验证检查inspect用户、只读根、tmpfs、volume、网络与健康。T4生命周期验证发信号、断依赖、重建和恢复数据。

本章环境只达到T1。docker --version返回28.4.0，但docker info无法连接daemon。版本命令证明CLI存在，不证明Server版本、BuildKit、镜像或运行结果。

验收报告必须逐项写ACTUAL或UNVERIFIED。若无法启动daemon，正确结果是“未验证”，不是把Python字符串测试当镜像build。

## 15. 故障矩阵

|故障|最早阶段|首个可信证据|错误处理|
|---|---|---|---|
|FROM latest|源码审计|FROM行无digest|固定已审核digest并建更新流程|
|.env进入上下文|上下文审计|文件清单与ignore|移出、轮换真实秘密、清历史|
|builder全量复制到runtime|镜像层|Dockerfile与history|只复制明确制品|
|最终USER root|源码/inspect|最后USER与Config.User|创建非root用户并修权限|
|shell ENTRYPOINT吞信号|进程生命周期|进程树、stop后KILL|exec形式或正确exec转交|
|应用写/app|只读运行|EROFS与具体路径|tmpfs/volume或修应用|
|数据库写可写层|重建测试|容器删除后数据丢|命名volume并做恢复测试|
|只监听127.0.0.1|网络|容器内ss与外部连接|监听容器接口并限制网络|
|把EXPOSE当发布|网络配置|无端口映射|显式-p或编排入口|
|digest永不更新|供应链|漏洞与基线过期|受控PR更新、扫描与回滚|

## 16. 概念卡

### 16.1 镜像与容器

镜像是不可变模板；容器是运行实例和临时状态。修改容器不会更新原镜像。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.2 层与文件

层保存差异；后层删除前层文件可能仍在历史层中，因此秘密一旦COPY就不能靠后续rm消失。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.3 tag与digest

tag便于人读但可变；digest固定内容。生产证据通常同时保留语义tag和digest。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.4 多阶段与多容器

多阶段发生在一次镜像构建中；多容器是运行时服务拆分，下一章由Compose声明。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.5 builder与runtime

builder需要编译工具；runtime只需运行制品。最终攻击面由runtime决定。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.6 缓存与复现

缓存加速既有输入；复现要求输入可控。缓存命中本身不是输出正确证据。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.7 ARG与secret mount

ARG可能进入元数据；secret mount只在构建指令期间暴露，但脚本仍不得复制秘密。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.8 USER与授权

USER降低OS权限；Java业务授权仍检查用户、租户和资源。两层不能替代。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.9 EXPOSE与publish

EXPOSE是文档元数据；-p/Compose ports才向宿主发布。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.10 可写层与volume

可写层随容器删除；volume独立持久。持久不等于已备份。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.11 bind与volume

bind暴露明确宿主路径；volume由Docker管理。选择取决于生命周期、权限与可移植性。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.12 tmpfs与volume

tmpfs适合临时敏感/高速数据且不持久；volume用于需跨容器生命周期的数据。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.13 read-only与零写入

只读根不代表进程完全不写；所需/tmp、cache、pid应成为显式tmpfs。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.14 PID1与应用主线程

PID1是容器进程边界；Java主线程内部结构不同。停止证据看信号与退出，不看类名。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.15 STOPSIGNAL与处理信号

声明信号只是配置；实际处理必须运行测试并观察宽限期退出。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.16 health与ready

进程存活不等于可接请求；readiness应反映流量条件，避免与重启策略混淆。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.17 容器DNS与固定IP

自定义网络按名称解析；重建IP会变，客户端应重新解析和重连。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.18 最小镜像与完整运行

删除不需要组件降低攻击面，但不能删掉CA、字体等真实运行依赖。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.19 静态PASS与运行PASS

静态规则证明文本满足模式；运行PASS需要daemon、真实镜像和可观察行为。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.20 镜像扫描与无风险

扫描报告是已知数据库与组件证据，不证明零漏洞，也不发现所有业务缺陷。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.21 不可变发布与紧急进容器修复

生产修复应改源码重建并晋级同一制品；手工修改无法追溯且会在重建时消失。排错时先说明证据层级，避免把配置意图当成运行事实。

### 16.22 Java事实与容器状态

工单事实属于Java数据库事务；容器Up/Down只描述进程，不改业务真相。排错时先说明证据层级，避免把配置意图当成运行事实。

## 17. 实操路线

先运行example，观察静态解析器如何拒绝单阶段、未固定FROM、root与shell ENTRYPOINT。再查看lab的Dockerfile.fixture，明确重复digest不可pull，context-files.txt只是合成构建上下文清单。

运行 public exercise 的未改 starter 应得到 `EXPECTED_RED`/41。依次实现 digest、非 root 和秘密文件检测并重跑原测试；完成后原验证器返回 `EXERCISE_GREEN`/0，partial/unknown/基础设施失败返回 43。private solution 提供最小参考，但仍没有信号或只读运行证明。

具备daemon后另建真实实验：替换为仓库存在的digest；执行build并保存image ID/RepoDigest；inspect用户；以--read-only和/tmp tmpfs启动；挂命名volume；curl健康；docker stop计时；删除重建验证卷。所有命令与结果单独保存，不回写成静态fixture的结论。

## 18. 自测题

1. 为什么删除容器会丢可写层但不一定删除命名volume？
2. 为什么latest不是可复现引用？
3. 固定digest后怎样获得安全更新？
4. 多阶段构建怎样避免JDK与node_modules进入runtime？
5. 为什么在后续RUN rm秘密不能消除历史层泄露？
6. ARG/ENV为何不适合构建秘密？
7. USER 10001能保证哪些事，不能保证哪些事？
8. JSON ENTRYPOINT与shell形式对信号路径有何差异？
9. STOPSIGNAL存在为何仍需真实stop测试？
10. read-only根下/tmp和Nginx cache应怎样处理？
11. EXPOSE为何不等于宿主可访问？
12. 静态审计通过为何不能声称镜像扫描、信号和卷已验证？

## 19. 120秒复述模板

镜像是由固定输入构建的只读层与配置，容器是共享主机内核的隔离进程并带临时可写层。生产Dockerfile用固定digest、多阶段构建和最小runtime，秘密不进上下文、ARG、ENV或层，最终USER非root并用exec入口。应用代码保持不可变；临时写入放tmpfs，持久数据放volume，只有必要入口发布端口。PID1必须真实接收TERM并在宽限期退出，read-only、健康、卷和网络都需daemon运行证据。Java继续拥有工单事实与授权。当前资产只是静态合同，没有真实镜像或容器证据。

## 20. 官方资料与当前验证边界

截至2026-07-24核对的官方一手资料：

- Docker Build best practices：https://docs.docker.com/build/building/best-practices/
- Multi-stage builds：https://docs.docker.com/build/building/multi-stage/
- Build secrets：https://docs.docker.com/build/building/secrets/
- Running containers：https://docs.docker.com/engine/containers/run/
- Dockerfile reference：https://docs.docker.com/reference/dockerfile/

本机实际读取到Docker CLI 28.4.0；docker info无法连接/Users/youren/.docker/run/docker.sock，因此Server版本、真实build、registry digest、扫描、PID1、只读根、volume与网络均UNVERIFIED。示例验证的是Python静态审计，合成digest明确不可作为制品身份。
