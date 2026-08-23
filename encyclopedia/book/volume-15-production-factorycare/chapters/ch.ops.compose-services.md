---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.compose-services
title: Compose 多服务、配置、健康检查与依赖
responsibility: 用 Compose 声明应用、数据库和代理的网络、卷、配置和健康合同，区分启动顺序与真正就绪，不把 Compose 当生产编排器。
volume: '15'
order: 4
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.compose-services.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.docker-production
version_surfaces:
- linux
- ubuntu-server-26.04
- docker
- docker-compose
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Compose 多服务、配置、健康检查与依赖”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-compose-topology
  - ops-compose-readiness
  covers_topics:
  - ops.compose-service
  - ops.compose-network
  - ops.compose-volume
  - ops.compose-profile
  - ops.compose-env
  - ops.healthcheck
  - ops.startup-dependency
  - ops.restart-policy
  uses_capabilities:
  - foundation.docker-runtime
  - ops.linux-service-network
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Compose 多服务、配置、健康检查与依赖”构建可运行程序与测试：编排 FactoryCare API、PostgreSQL 和 Nginx
    夹具，使用健康检查、命名卷、隔离网络与 profile 验证冷启动和重启；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-compose-topology
  - ops-compose-readiness
  covers_topics:
  - ops.compose-service
  - ops.compose-network
  - ops.compose-volume
  - ops.compose-profile
  - ops.compose-env
  - ops.healthcheck
  - ops.startup-dependency
  - ops.restart-policy
  uses_capabilities:
  - foundation.docker-runtime
  - ops.linux-service-network
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: compose-cold-start-dependency-failure-test-volume-persistence-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“只用 depends_on 当数据库就绪、所有服务暴露宿主端口、数据写入临时层或重启掩盖永久配置错误”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-compose-topology
  - ops-compose-readiness
  covers_topics:
  - ops.compose-service
  - ops.compose-network
  - ops.compose-volume
  - ops.compose-profile
  - ops.compose-env
  - ops.healthcheck
  - ops.startup-dependency
  - ops.restart-policy
  uses_capabilities:
  - foundation.docker-runtime
  - ops.linux-service-network
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Compose 多服务、配置、健康检查与依赖

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《镜像层、容器、卷、网络与运行时边界》](ch.ops.docker-production.md)：多服务编排要求每个镜像已具备明确进程、卷、网络和健康边界。
<!-- END GENERATED LEARNING PREREQUISITES -->

Docker Compose把一组容器的服务、网络、卷、配置、秘密、健康和依赖写成声明文件。它解决“如何在一个Compose项目中重复得到同一拓扑”，不自动解决跨主机调度、滚动升级、自动扩缩、分布式存储或高可用控制面。Docker官方也提供单服务器生产使用指南，因此“不把Compose当生产编排器”不是说它永远不能承载生产，而是不能把单主机Compose误当Kubernetes式集群编排能力。

本章围绕FactoryCare的Java API、PostgreSQL和Nginx代理建立最小拓扑。当前本机Docker Compose CLI v2.39.4可执行docker compose config并实际解析归一化fixture；Docker daemon未运行，所以没有启动容器、拉取镜像、观察health、重启或验证volume持久。每项结论都标ACTUAL配置或UNVERIFIED运行。

## 1. Compose项目、模型与服务

Compose文件顶层常见services、networks、volumes、configs、secrets和name。service不是某个固定容器ID，而是一类容器的运行声明：镜像、命令、环境、挂载、网络和健康。docker compose up把模型收敛为容器等资源。

项目名为资源提供命名作用域。默认可能来自目录，也可由-p、COMPOSE_PROJECT_NAME或顶层name决定。不同目录若意外使用同一项目名可能互相影响；自动化应显式设定并在down前确认目标。

Compose V2命令是docker compose，而旧docker-compose独立二进制属于历史表面。教材使用Compose Specification与当前CLI，不把顶层version字段当能力开关；具体字段支持仍以当前官方参考和docker compose config为准。

service名称在同一网络中成为稳定DNS名称。容器重建后IP可能变化但名称保持，应用应连接db:5432而不是记录旧IP。

## 2. 三服务FactoryCare拓扑

db服务只加入data网络，挂命名卷到PostgreSQL数据目录，并拥有pg_isready健康检查。它不发布宿主5432。api同时加入data和edge：向内连接db，向外被proxy访问；它不发布8080。

proxy只加入edge并发布唯一宿主入口8443。这样互联网侧无法直接绕过Nginx访问Java，也无法接触数据库。网络隔离不是应用授权，Java仍验证令牌、租户和资源。

调试toolbox放入debug profile，默认up不启动。显式启用profile或直接目标服务时才加入。工具容器不应长期持有生产秘密，也不应默认连接全部网络。

每个image使用真实部署时应固定digest。本章fixture用重复字符的合成digest，仅让Compose解析与静态策略测试，不能pull。

## 3. 启动顺序不是就绪

短写depends_on: [db]只建立创建/停止顺序。Docker官方Startup order文档明确：Compose通常等容器running，不等应用ready。PostgreSQL进程已启动时可能仍在恢复，API立即连接会失败。

长语法condition: service_healthy要求依赖先通过healthcheck。db定义pg_isready，api的depends_on.db.condition为service_healthy；proxy同样等待api健康。这把“就绪”变成可观测合同。

service_started适合只需进程已创建的依赖；service_completed_successfully适合迁移等一次性任务；service_healthy适合持续服务。选择要对应语义，不是全部写healthy。

即使依赖健康后启动，运行期间依赖仍可能故障。Java必须有连接超时、有限重试、连接池恢复和错误响应，不能永远依赖启动门。Compose声明解决冷启动门，不替代应用韧性。

## 4. 健康检查设计

healthcheck.test可用CMD数组或CMD-SHELL。CMD避免额外shell解析；CMD-SHELL便于变量与复合命令，但要正确转义Compose插值。命令必须存在于最终镜像，不能在builder有curl而runtime没有。

interval定义间隔，timeout限制单次，retries决定连续失败次数，start_period给冷启动宽限。参数过短会误杀慢启动，过长会让故障长时间不可见。基于实际分位数与恢复目标设定。

PostgreSQL pg_isready只能说明接受连接，不证明目标Schema迁移完成。API readiness可检查自身完成启动与关键依赖策略；liveness不宜因短暂数据库慢就失败造成重启风暴。

health状态是容器元数据，不会自动成为外部负载均衡条件。proxy是否只把流量给ready api还取决于代理和拓扑。本地Compose单实例常依赖启动顺序与应用返回，集群需要专门编排器。

## 5. depends_on中的restart与服务restart policy

depends_on子项restart: true表示Compose显式更新/重启依赖时，重启依赖方以重新连接。Docker官方示例明确这是由Compose操作触发的依赖重启行为。它和service顶层restart不是同一字段。

service restart policy如no、always、on-failure、unless-stopped决定daemon如何处理容器退出。策略不能修复永久错误。密码错误若always重启，会不断刷日志并遮蔽第一条异常。

on-failure可带次数的具体表达需查当前规范；unless-stopped适合单机长期服务但仍要监控。人工docker compose stop与daemon重启的语义也需在目标版本实测。

Java API应在永久配置错误时快速失败并给稳定日志，平台保存证据并报警；不要用无限应用内循环加restart双层放大。

## 6. 环境变量：插值与容器环境分开

Compose文件中的美元插值发生在CLI渲染模型时；service.environment/env_file决定进入容器的环境。宿主shell/.env参与插值不意味着变量自动进入容器，必须理解两个阶段。

Docker官方当前给出容器环境值优先级：docker compose run -e最高；由shell或env文件插值进environment/env_file的值其次；Compose environment；Compose env_file；最后镜像ENV。具体细节以官方表为准。

docker compose config能显示合并与插值后的模型，因此部署前保存脱敏输出很重要。注意它可能展开敏感值，不能把完整config直接上传公开CI日志。

环境变量适合非敏感配置。密码等使用Compose secrets或外部secret store，并让应用支持_FILE路径。把密码直接写compose.yaml、.env后提交或镜像ENV都不安全。

## 7. secrets与configs

顶层secret只定义来源，不自动授予服务；service.secrets显式授权并挂到/run/secrets等路径。fixture从环境提供合成密码源，归一化配置保存的是来源名，不运行容器。

Compose secret的安全保证取决于后端。单机Compose文件挂载与Swarm secret并非相同威胁模型。官方CLI docker secret是Swarm功能，不能把名称相似当作同一加密分发机制。

Java读取DB_PASSWORD_FILE，避免秘密出现在进程环境与普通config输出，但文件权限、日志和轮换仍要治理。应用不得把读到的值打印或写回错误报告。

configs适合非敏感配置文件。无论secret/config，版本变更如何触发容器重建、旧值何时失效都需实际部署策略。

## 8. 网络隔离

未声明时Compose创建项目default网络，所有服务通常可相互通信。为了表达最小路径，显式data与edge：data设置internal，db只加入data；proxy只加入edge；api作为受控桥接点加入两者。

internal网络限制外部连接语义要在目标Engine实测；它不等于主机防火墙或云安全组。容器一旦加入两个网络就能在应用层桥接数据，Java仍要限制出站和输入。

只有proxy使用ports。expose可表达容器端口但不发布宿主。ports可能绑定0.0.0.0，若只需本机调试应显式127.0.0.1:端口；生产入口由主机防火墙与TLS策略约束。

网络名称和容器IP是运行事实；docker compose config只证明声明结构。daemon未启动时不能声称未声明服务无法跨网络访问。

## 9. volumes与数据生命周期

顶层volumes声明命名卷；service.volumes把它挂到准确目标。PostgreSQL数据目录必须匹配镜像实际版本，否则写在挂载外的可写层仍会丢。升级数据库镜像时复核目录与迁移。

docker compose down默认删除容器和网络，但通常保留命名卷；down -v会删除卷。操作前确认环境和备份，自动化不要随手加-v。匿名卷、bind和命名卷语义不同。

持久性验证不是看YAML有volumes。真实Oracle是写入标记数据、重建db容器、重新查询仍存在；再做备份恢复。fixture只静态断言mount type=volume和target。

卷权限要匹配数据库UID，macOS Desktop还经过虚拟机文件系统。性能与权限必须在目标主机验证，不能由Linux路径字符串推断。

## 10. profiles

profiles让调试、迁移或可选工具按需启用。未标profile的核心服务默认启用；有profile的服务只在profile激活时启用。Docker官方说明显式目标某个profile服务时，它会自动启用自身及依赖，但同profile其他服务不会自动全部启动。

不要给核心db/api随意加profile，否则默认up可能得到不完整应用。将admin UI、调试shell、一次性迁移放profile，并保持最小网络/secret权限。

profile不是安全边界。能运行docker compose命令的人可以启用它。生产Compose文件可完全不包含危险debug工具，或通过独立overlay控制。

验证时分别运行docker compose config与--profile debug config，比较服务集合。本章实际parser用--profile debug验证toolbox声明，但没有启动。

## 11. 多文件与环境覆盖

Compose支持-f组合基础与环境文件。覆盖规则对mapping、sequence和特殊字段并非简单文本替换，必须用docker compose config查看最终模型。不要靠目测认为生产关闭了某端口。

基础文件放稳定拓扑，production overlay移除开发bind、设置restart与资源边界、选择真实digest。环境差异应是配置，不应在生产重新build不同jar。

COMPOSE_FILE、工作目录与项目目录影响相对路径和.env查找。CI显式传-f、--project-directory、--env-file和-p，保存命令，避免从不同cwd得到不同模型。

合并后的模型可能含secret值或宿主绝对路径，证据需要脱敏。配置hash应基于规范化且安全的投影，不对秘密做可逆保存。

## 12. 冷启动验证

真实冷启动从无容器但保留/新建卷开始：docker compose up -d；观察db created→starting→healthy，随后api启动并healthy，最后proxy接流量。记录events、ps、health inspect与日志时间线。

错误注入一：db健康命令失败，api不得进入可接流量状态。错误注入二：短depends_on，重现API连接失败。错误注入三：移除卷，重建后标记数据丢失。错误注入四：额外发布db端口，宿主探针意外可连。

启动成功不是功能成功。通过proxy访问API，验证状态、正文与请求ID；直接宿主访问8080/5432应失败；toolbox默认不存在。测试后清理但保留所需失败证据。

本章daemon离线，没有执行以上步骤。Compose config成功不能改写为compose-cold-start通过。

## 13. 单服务重启与更新

docker compose restart db只重启既有容器，不应用Compose配置变化；up -d在模型变化时可能重建。命令语义需区分。部署更新一般验证镜像digest并用up收敛。

db重启期间api应返回受控503或重连，不无限阻塞。db恢复后API连接池恢复。depends_on只负责创建阶段，除非使用特定restart联动，也不替代应用重连。

更新api不应重建db，可使用目标服务与--no-deps策略，但要确认配置/依赖是否同时变化。每次操作记录前后container ID、image digest、health和服务结果。

Compose单机更新通常不是零停机滚动发布。若业务要求多副本、负载均衡和自动回滚，应采用适合的编排与发布系统，而不是给Compose赋予不存在的控制面。

## 14. Nginx代理在拓扑中的位置

proxy是唯一入口，等待api健康并只加入edge。它不直接连接db。下一章配置TLS、forwarded headers、API location与静态fallback。

健康依赖不等于Nginx运行时自动移除不健康上游。单api容器故障时应给明确502/503和追踪；多上游与主动健康能力需按Nginx版本/产品验证。

Java看到的来源信息来自proxy，但只在可信代理边界内接受。网络隔离帮助限制伪造路径，Java安全配置仍应明确可信代理。

静态资源可内置proxy镜像，或独立frontend服务。选择要保持制品digest和缓存合同，不因开发便利挂源码bind到生产。

## 15. 静态策略Oracle

本章fixture实际由docker compose config --format json解析，说明当前CLI接受语法、变量来源和模型。Python再对归一化JSON检查镜像digest格式、发布端口、volume target、health依赖、网络集合、restart与debug profile。

这比正则读YAML更可靠，但仍是配置级。合成镜像不存在，health命令未执行，secret未挂载，internal网络未创建，volume未写入。

public exercise 用危险模型：`service_started`、所有服务 ports、数据库无卷、`restart: always`。精确 starter audit 应稳定 `EXPECTED_RED`/41；修复后同一验证器返回 `EXERCISE_GREEN`/0；partial/unknown/基础设施失败返回 43。private solution 只修静态规则。

证据报告应写ACTUAL Compose CLI v2.39.4 config parse；UNVERIFIED Engine、image pull、cold start、health transition、restart、network isolation和volume persistence。

## 16. 故障矩阵

|故障|最早证据|为何危险|修复|
|---|---|---|---|
|短depends_on|config归一化condition|只等running|healthcheck+service_healthy|
|health命令不存在|容器health日志|永远unhealthy|把探针放runtime并独立测试|
|db发布5432|config ports/宿主监听|绕过服务边界|仅内部data网络|
|db无命名卷|config mount与重建|容器删除丢数据|准确目标命名卷|
|所有服务default网络|config networks|无最小隔离|data/edge分段|
|password写environment明文|config/log|泄露|secret文件/外部store|
|restart always掩盖配置错|重启计数与首条日志|风暴|分类永久错误、告警|
|debug服务默认启动|profile集合|扩大攻击面|opt-in profile或独立文件|
|环境overlay仍保留bind|config最终模型|生产代码可变|移除开发挂载|
|把config通过当冷启动|证据类型|虚假完成|daemon运行故障矩阵|

## 17. 概念卡

### 17.1 服务与容器

service是声明模板；容器是某次收敛产生的实例。重建实例不改变服务名合同。每个判断都要注明来自归一化配置还是运行时观察。

### 17.2 项目名与目录名

目录名常参与默认项目名，但自动化应显式-p，避免跨目录资源冲突。每个判断都要注明来自归一化配置还是运行时观察。

### 17.3 启动与就绪

running表示进程启动；healthy表示探针通过；业务可用还需端到端请求。每个判断都要注明来自归一化配置还是运行时观察。

### 17.4 depends_on与重连

depends_on控制创建门；运行中依赖故障靠应用超时、重试和连接恢复。每个判断都要注明来自归一化配置还是运行时观察。

### 17.5 healthcheck与功能测试

health轻量判定流量条件；完整功能测试覆盖更深业务，不应每几秒执行。每个判断都要注明来自归一化配置还是运行时观察。

### 17.6 depends_on restart与service restart

前者描述显式依赖操作联动；后者描述容器退出后的daemon策略。每个判断都要注明来自归一化配置还是运行时观察。

### 17.7 插值与环境注入

${VAR}在Compose模型渲染时解析；environment决定容器获得哪些键。每个判断都要注明来自归一化配置还是运行时观察。

### 17.8 .env与secret

默认.env帮助插值，不是加密保险箱；秘密不应因被.gitignore就视为安全分发。每个判断都要注明来自归一化配置还是运行时观察。

### 17.9 secret定义与授权

顶层定义来源，service.secrets才授予某服务。最小授权避免所有服务共享。每个判断都要注明来自归一化配置还是运行时观察。

### 17.10 default网络与分段网络

default简便但连接面宽；data/edge表达谁应与谁通信。每个判断都要注明来自归一化配置还是运行时观察。

### 17.11 ports与expose

ports发布到宿主；expose/容器端口只表达内部可用，不自动公开。每个判断都要注明来自归一化配置还是运行时观察。

### 17.12 internal与绝对隔离

internal是Docker网络属性，不替代主机防火墙、应用授权与出站治理。每个判断都要注明来自归一化配置还是运行时观察。

### 17.13 命名卷与备份

命名卷跨容器生命周期；备份是独立副本与恢复过程。每个判断都要注明来自归一化配置还是运行时观察。

### 17.14 down与down -v

前者通常保留命名卷；后者请求删卷，可能破坏数据。执行前必须确认。每个判断都要注明来自归一化配置还是运行时观察。

### 17.15 profile与权限

profile控制启用集合，不限制有daemon权限的人。危险工具仍需移出生产。每个判断都要注明来自归一化配置还是运行时观察。

### 17.16 config与up

config解析归一化模型且不需启动容器；up才请求daemon创建运行资源。每个判断都要注明来自归一化配置还是运行时观察。

### 17.17 Compose与集群编排

Compose适合声明单机多容器；不提供跨节点调度、高可用控制面和完整滚动发布。每个判断都要注明来自归一化配置还是运行时观察。

### 17.18 restart与自愈

重启可恢复瞬态进程退出；不能修密码错误、坏迁移或永久网络配置。每个判断都要注明来自归一化配置还是运行时观察。

### 17.19 固定服务名与变化IP

应用使用服务DNS并重连；不要把容器IP写数据库或配置。每个判断都要注明来自归一化配置还是运行时观察。

### 17.20 Java事实与Compose状态

Compose管理进程拓扑；工单事实和权限仍由Java事务管理。每个判断都要注明来自归一化配置还是运行时观察。

### 17.21 实际config与真实运行

CLI解析通过是ACTUAL配置证据；health、网络和卷需要daemon实验。每个判断都要注明来自归一化配置还是运行时观察。

### 17.22 合成digest与真实digest

格式相同不代表仓库存在。真实部署从registry解析并记录RepoDigest。每个判断都要注明来自归一化配置还是运行时观察。

## 18. 实操路线

运行examples与labs，找到ACTUAL和UNVERIFIED两行。用docker compose config查看services、networks与volumes；再用--profile debug确认toolbox出现。不要运行up，因为合成digest不可pull且daemon当前离线。

运行 public exercise，先确认未改 starter 的 `EXPECTED_RED`/41。实现四个检查：API 等待 healthy、数据库命名卷、仅 proxy 发布、data 网络 internal；同一验证器必须转为 `EXERCISE_GREEN`/0，尚未完成或未知形状为 43。阅读 private solution 后增加 image digest 与 healthcheck 检查。

未来daemon可用时替换为真实镜像digest，按冷启动、依赖失败、db重启、数据重建和网络拒绝矩阵执行。保存命令、版本、镜像digest、events、health、curl与数据查询；不把本次config证据覆盖成运行证据。

## 19. 自测题

1. 短depends_on为什么不能证明数据库ready？
2. service_healthy解决了什么，没解决什么？
3. healthcheck命令为什么必须存在于runtime镜像？
4. depends_on restart与顶层restart差别是什么？
5. 环境插值与容器environment是哪两个阶段？
6. docker compose config日志有什么secret风险？
7. db为何只加入data且不发布端口？
8. 命名卷声明怎样用真实重建测试验证？
9. profile为何不是安全边界？
10. restart always为什么可能掩盖永久错误？
11. Compose在哪些单机生产场景可用，哪些集群能力没有？
12. 本章哪些证据是ACTUAL，哪些仍UNVERIFIED？

## 20. 120秒复述模板

Compose把服务、网络、卷、配置、secret、健康和依赖声明为单机应用模型。FactoryCare让db只进internal data并挂命名卷，proxy只进edge并发布唯一端口，api桥接两网。depends_on短语法只管顺序；真正冷启动门用healthcheck与service_healthy，但运行中重连仍由Java处理。环境插值和容器环境要分开，秘密经最小service授权的secret文件进入。restart不修永久配置，profile不提供权限。docker compose config证明当前CLI接受最终模型，不证明daemon里的冷启动、健康、重启、隔离和持久。Compose可用于合适单服务器部署，但不是跨主机生产编排控制面。

## 21. 官方资料与当前验证边界

截至2026-07-24核对的Docker官方资料：

- Compose startup order：https://docs.docker.com/compose/how-tos/startup-order/
- Compose services reference：https://docs.docker.com/reference/compose-file/services/
- Networking in Compose：https://docs.docker.com/compose/how-tos/networking/
- Profiles：https://docs.docker.com/compose/how-tos/profiles/
- Environment precedence：https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/
- Compose secrets：https://docs.docker.com/reference/compose-file/secrets/
- Use Compose in production：https://docs.docker.com/compose/how-tos/production/

本机ACTUAL：Docker Compose v2.39.4-desktop.1成功将fixture规范化为JSON并通过静态策略。UNVERIFIED：Docker Server不可连接、合成镜像不可pull，故未验证cold start、health、restart、网络隔离、secret挂载和volume persistence。
