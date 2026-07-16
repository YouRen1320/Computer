---
schema_version: 2
edition: 2026.2-draft
id: ch.foundations.docker-basics
title: 镜像、容器、卷、端口与容器网络
responsibility: 教授容器运行时和持久化边界，不进入生产镜像加固、Compose 编排或 Kubernetes
volume: '00'
order: 14
level: L1
status: drafting
path: book/volume-00-computer-foundations/chapters/ch.foundations.docker-basics.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.network-layers
- ch.foundations.testing-oracles
version_surfaces:
- docker
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释镜像、容器、卷、端口与容器网络的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - docker-image-container
  - docker-storage-network
  covers_topics:
  - docker.image-layer
  - docker.container-process
  - docker.port-publish
  - docker.volume-bind-mount
  - docker.container-network
  - docker.cleanup
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  - foundation.network-transport
  - foundation.docker-runtime
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 运行一个写入数据并暴露端口的容器，对比镜像层、容器可写层、bind mount、named volume 和容器网络行为
  covers_topic_groups:
  - docker-image-container
  - docker-storage-network
  covers_topics:
  - docker.image-layer
  - docker.container-process
  - docker.port-publish
  - docker.volume-bind-mount
  - docker.container-network
  - docker.cleanup
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  - foundation.network-transport
  - foundation.docker-runtime
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入端口未发布、卷挂错路径和删除容器后数据丢失，分别用 inspect/log/文件证据定位并修复
  covers_topic_groups:
  - docker-image-container
  - docker-storage-network
  covers_topics:
  - docker.image-layer
  - docker.container-process
  - docker.port-publish
  - docker.volume-bind-mount
  - docker.container-network
  - docker.cleanup
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  - foundation.network-transport
  - foundation.docker-runtime
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 镜像、容器、卷、端口与容器网络

“服务装进 Docker 了”没有说明服务是否在运行、数据放在哪里、主机能否访问、另一个容器该连哪个地址，也没有说明删除哪个资源会丢数据。把镜像、容器、卷、端口和网络混成一个“盒子”，正是许多开发环境事故的起点。

本章建立五条边界：镜像提供不可变运行模板；容器是带主进程和可写层的运行实例；持久数据要离开容器可写层；端口发布连接主机与容器端口；用户定义网络连接容器并提供名称解析。最后用逐项清理证明资源所有权。

正文只到单机 Docker 基础，不进入生产镜像加固、Compose、Swarm 或 Kubernetes。默认实验无需 Docker daemon；真实 daemon 实验必须显式授权并使用已经存在的本地基础镜像，全程不 pull、不登录、不访问公网。

## 一、从主机进程到隔离进程

普通程序也是进程：它有可执行代码、参数、环境、文件描述符、网络端口和生命周期。容器没有改变“应用最终由进程执行”这个事实，而是让进程在内核提供的隔离与资源控制边界中运行，并给它准备一套文件系统和网络视图。

Docker 官方入门把容器概括为隔离进程。多个 Linux 容器通常共享宿主内核，而虚拟机一般包含自己的客户操作系统和内核。这能帮助理解容器较轻，但不能推出“容器天然安全”或“不同宿主平台完全相同”。Docker Desktop 在 macOS/Windows 上通常还通过 Linux VM 提供 daemon 环境，宿主路径、网络和权限会经过额外层。

### 容器不是迷你服务器

一个容器可以运行多个进程，但常见设计围绕一个主要职责和主进程。容器状态 `running` 表示主进程仍在；主进程退出，容器通常转为 stopped/exited。`docker exec` 是在已有运行容器中再启动进程，不会把临时手改自动写回镜像。

诊断“容器马上退出”先看：

1. 容器状态和退出码；
2. 主进程命令与参数；
3. stdout/stderr 日志；
4. 配置、权限和文件是否存在；
5. 是否误把应当前台运行的服务放到后台后让主进程结束。

不要先用无限 sleep 把容器强行保持 running；那只隐藏真正进程退出原因。

## 二、镜像是分层模板，标签不是内容身份

容器镜像是包含运行所需文件、二进制、库和配置的标准化包。Docker 官方文档强调两个基础性质：镜像创建后不可直接修改，只能构建新镜像或在其上增加变化；镜像由层组成，每层表达一组文件系统增加、删除或修改。

例如教学镜像可抽象为：

```text
层 1：可信本地基础运行时
层 2：复制 /srv/factorycare/index.html
镜像摘要：sha256:...
```

从这个镜像创建两个容器时，只读镜像层可共享；每个容器得到自己的可写层。容器 A 在 `/tmp/a` 写文件，不会修改镜像，也不会让容器 B 自动看到。

### 层的缓存与构建顺序

镜像层可复用，因此 Dockerfile 前面不变的步骤有机会复用构建缓存。常见设计把变化较慢的依赖声明与安装放在源码复制前，以减少无关重建；但具体缓存键和 BuildKit 行为属于后续构建专章。本章只要求能从历史/inspect 信息区分镜像层与容器写入。

### tag 与 digest

`factorycare-api:local` 是可读标签，可以被重新指向另一镜像；内容 digest 与具体字节内容绑定，更适合追溯。使用标签便于开发，不应把标签文字等同不可变身份。真实实验要求基础镜像已经在本地且来源/摘要可追溯，但不会假装本地存在就是可信。

### Dockerfile 中的 EXPOSE

`EXPOSE 8080` 描述镜像预期监听的端口，是元数据和协作约定；它不会自动在主机创建 `18080→8080` 映射。主机访问需要容器运行时的 publish 配置。这一区分会在端口故障实验中直接验证。

## 三、容器可写层何时保留、何时消失

默认情况下，容器运行中创建的未挂载文件写入该容器独有的可写层：

```text
只读镜像层
    ↑
容器 A 可写层：/data/a.txt
容器 B 可写层：空
```

需要精确区分三种动作：

- **stop/start 同一个容器**：可写层仍属于该容器，通常还在；
- **remove 容器**：容器及其可写层被删除；
- **从同一镜像新建容器**：得到新的空可写层，不继承旧容器写入。

所以“重启后数据还在”不能证明持久化设计正确；你可能只是重启了同一个容器。真正验证应 stop、remove，再从同一镜像创建新容器。若业务数据应保留，它必须通过 volume、bind mount 或外部存储跨越容器生命周期。

容器可写层适合临时状态、可重建缓存或运行时少量文件，不适合作为唯一数据库和工单附件存储。Docker 官方存储文档明确指出，销毁容器后可写层数据不持久，且每个容器的可写层独有。

## 四、named volume：由 Docker 管理的持久数据

volume 是 Docker daemon 管理的持久数据存储。创建 named volume 后，把它挂到容器路径，例如概念上：

```text
fc-basics-data  →  /srv/factorycare
```

应用写 `/srv/factorycare/index.html`，实际数据落在 volume。停止并删除容器，再把同一 named volume 挂到新容器同一路径，数据应仍在。删除容器和删除 named volume 是两个独立动作。

### named 与 anonymous volume

named volume 有显式名称，便于重用、备份和逐项清理。anonymous volume 由 Docker 分配名称；`--rm` 对匿名卷有特定清理语义，而显式 named volume 通常不会随容器自动删除。执行前要知道是哪一种，不能把“容器删了”当作卷状态证据。

### mount 会遮蔽镜像原内容

把 volume 挂到镜像中已有文件的非空目录，会让挂载内容在该路径上可见，原镜像内容被遮蔽而非真的删除。若新空卷挂到 `/srv/factorycare`，镜像原有 `index.html` 是否被复制、何时初始化取决于挂载类型和具体行为；生产初始化不能依赖模糊猜测。实验通过显式 writer 写入 expected 数据。

### 不直接操作 daemon 的 volume 目录

Docker 官方文档说明 volume 由 daemon 管理，直接修改 daemon 存储位置属于不受支持行为，可能损坏数据。备份、恢复和迁移应使用经过验证的容器/API/工具流程，而不是进入内部目录手改。

## 五、bind mount：把明确主机路径映射进容器

bind mount 把 daemon 主机上的文件或目录直接映射到容器路径。它适合开发源码、明确配置或主机与容器交换文件：

```text
主机 /owned/lab-data  ↔  容器 /exchange
```

与 volume 相比，bind mount 更依赖主机目录结构。远程 daemon 时，source 是 daemon 主机路径，不是 CLI 客户端路径；Docker Desktop 会在 VM 与原生主机之间做路径共享处理。

### 默认可写意味着宿主风险

Docker 官方 bind mount 文档提醒：bind 默认可写，容器进程可修改主机文件，影响非 Docker 程序。只读需求应使用 `readonly`/`ro`；不要把 `/`、`/etc`、整个 home、Docker socket 或生产数据目录可写挂进教学容器。

本章离线模型只允许系统为本次实验创建的临时根目录，故意拒绝 `/etc`。真实脚本也只 bind 自己的 `mktemp` 目录，清理时只删除自己写入的精确文件，不使用递归清理。

### volume 与 bind 的选择

| 维度 | named volume | bind mount |
| --- | --- | --- |
| 位置管理 | Docker daemon | 用户明确主机路径 |
| 与主机直接交换 | 不应直接摸内部路径 | 适合明确共享 |
| 主机结构依赖 | 较低 | 较高 |
| 默认写宿主风险 | 由 Docker 管理边界 | 可直接修改 source |
| 常见用途 | 数据库/服务持久数据 | 开发源码、配置、交换文件 |

这不是绝对规则。选择应写明数据所有者、备份、权限、迁移和删除策略。

## 六、卷挂错路径为何“当前有、重建丢”

这是本章核心故障：

```text
实际 mount target：/wrong
应用写入路径：      /expected/new.txt
```

容器内写入成功，因为 `/expected` 可在容器可写层创建；但 volume 位于 `/wrong`，从未收到数据。当前容器能读到文件，删除并重建后文件消失。

诊断不要只执行 `ls /expected`。组合三类证据：

1. **inspect**：Mounts 的 Type、Source、Destination、RW；
2. **logs/config**：应用实际数据目录；
3. **文件证据**：正确 mount 内是否有文件，容器 diff/可写层是否出现写入。

修复为 mount target 与应用路径完全一致，写入一个唯一值，stop/remove 容器，再用同一 volume 创建新容器读取。只 restart 同一容器不足以验收。

## 七、监听、EXPOSE 与 publish 是三层

网络前置知识告诉我们：服务先在某个地址和端口监听，客户端才能连接。Docker 增加了容器网络边界：

1. 应用在容器内监听，例如 `0.0.0.0:8080`；
2. 镜像可用 `EXPOSE 8080` 声明预期端口，但它不发布；
3. 运行容器时用 publish 建立主机地址/端口到容器端口的映射；
4. 客户端访问主机映射地址，而不是猜容器内部地址。

语义示例：

```text
127.0.0.1:18080  →  container:8080/tcp
```

前者是主机 loopback 与主机端口，后者是目标容器端口。写反会连接错误。

### 为什么本章固定 127.0.0.1

Docker 官方端口发布文档说明，不指定 host IP 时，端口默认发布到所有主机地址，可能被外部网络访问。教学服务不需要局域网暴露，因此显式使用 `127.0.0.1`。生产暴露策略还要结合防火墙、云安全组、反向代理、TLS 和认证，本章不展开。

### 端口未发布的诊断

主机 `curl localhost:18080` 失败时按层检查：

1. 容器是否 running，主进程是否退出；
2. logs 是否显示服务监听；
3. 容器内监听地址/端口是否正确；
4. inspect/`docker container port` 是否存在预期映射；
5. host IP 是否为预期，主机端口是否冲突；
6. 修复 publish 后重跑同一个请求。

没有 publish 时，同一用户定义网络中的另一个容器仍可能访问服务；“主机访问失败”与“容器网络不通”是不同问题。

## 八、容器网络：名称、隔离和 localhost

Docker bridge 网络让同一 daemon 主机上的容器通信。用户定义 bridge 相比默认 bridge 提供按容器名/alias 的自动 DNS 解析和更清晰隔离。FactoryCare 可概念化为：

```text
fc-basics-net
├── fc-basics-client
└── fc-basics-api:8080
```

client 可访问 `http://fc-basics-api:8080`，不需要为了容器间通信把 8080 发布到主机。publish 解决主机/外部进入，用户定义网络解决同一网络中的容器寻址。

### localhost 永远从当前网络命名空间看

API 容器里的 `localhost:5432` 指 API 容器自身，不是另一个数据库容器。要访问 db，应使用同一用户定义网络上的服务/容器名和容器端口。把主机映射端口绕回来通常增加复杂度，也可能扩大暴露面。

### 同网不等于无限授权

Docker 官方 bridge 文档说明，同一用户定义 bridge 上容器可相互通信并按名称解析；不同 bridge 默认隔离。网络连通不等于应用认证、租户隔离或加密已经完成。敏感服务仍需最小网络范围和应用层控制。

### DNS 名比容器 IP 稳定

容器替换后 IP 可改变，名字/alias 由网络解析到当前地址。不要把 inspect 看到的临时 IP 写进应用配置。若名字解析失败，检查两端是否加入同一网络、名字/alias 和目标端口，而不是立即写 `/etc/hosts`。

## 九、inspect、logs 与文件证据各回答什么

### inspect：声明与运行时状态

`docker inspect` 可显示镜像、命令、状态、Mounts、端口映射和网络连接。它回答“daemon 实际如何配置”，不证明应用一定正确使用这些配置。

### logs：主进程公开输出

`docker logs` 读取容器主进程的 stdout/stderr。它适合启动失败、监听地址、权限错误和应用写入路径，但应用若写独立文件且未转发，logs 可能没有。日志也可能含敏感数据，保存前脱敏。

### 文件与请求证据：可观察结果

持久化要用替换容器前后的唯一文件内容验证；端口要用主机请求；容器网络要从伙伴容器按名称请求；可写层可用 `docker container diff` 或受控文件检查。一个证据不能替代全部层。

### 首个可信失败

若容器因命令错误已退出，端口超时只是后果；先修主进程。若进程监听 8080、network request 成功，但 host inspect 没有 Ports 映射，首个可信边界是 publish 缺失。若 Mounts.Destination 是 `/wrong` 而日志写 `/expected`，路径不一致比“重建后文件不存在”更早、更具体。

## 十、资源清理要按所有权逐项进行

Docker 资源可能被其他项目共享。全局 `docker system prune`、`docker volume prune` 或强制删除会影响所有“当前未使用”的资源，不适合教学脚本和共享开发机默认操作。

本章策略是：

1. 使用每次唯一的 `fc-basics-*` 名称；
2. 创建前确认同名资源不存在，拒绝复用；
3. 只记录本次成功创建的资源；
4. 先正常 stop 主进程，再 remove 精确容器；
5. 确认没有引用后移除本次 volume 和 network；
6. 移除本次构建的教学 image，不移除用户提供的基础 image；
7. 不用 `--force`、prune 或通配批量删除；
8. 清理后逐项 inspect，预期资源不存在。

`docker run --rm` 适合短暂探针，但要理解它会自动删除容器并对匿名卷有相应行为。需要检查退出后文件系统时不要立即 `--rm`，先保存证据再定向删除。

## 十一、默认离线实验：不需要 Docker daemon

公开示例位于 [examples/encyclopedia/ch.foundations.docker-basics](../../../examples/encyclopedia/ch.foundations.docker-basics/README.md)。先预测，再运行：

```bash
ruby examples/encyclopedia/ch.foundations.docker-basics/verify.rb
```

离线模型会验证：

- 容器写入不改变 image digest；
- 未挂载数据在容器替换后消失；
- named volume 的 `WO-100` 跨 stop/remove/new container 保留；
- volume 挂 `/wrong` 时应用写 `/expected` 落入可写层；
- bind 到实验临时目录可见，`/etc` 被拒绝；
- 未 publish 的服务主机不可达；
- 同一用户定义网络按名称可达，不同网络不可达；
- `127.0.0.1:18080→8080` 可达，`0.0.0.0` 被安全模型拒绝；
- 只清理 `fc-basics-*` 精确资源，不执行 prune/force。

模型能让边界可证伪，但它不是 Docker Engine。它不验证真实 namespace、iptables、storage driver、Desktop VM、文件权限或 daemon 版本。

## 十二、可选真实 daemon 实验

真实脚本位于 [labs/encyclopedia/ch.foundations.docker-basics](../../../labs/encyclopedia/ch.foundations.docker-basics/README.md)。它默认拒绝执行；只有同时满足以下条件才启用：

1. 用户自行启动并确认 Docker daemon；
2. 本机已有可信且含 `python3` 的基础 image；
3. image 来源和摘要已记录；
4. 端口空闲，实验不含真实凭据或客户数据；
5. 已阅读脚本创建/删除的精确资源；
6. 显式设置 `ALLOW_FACTORYCARE_DOCKER_LAB=1`。

脚本先 `docker image inspect`，不存在就退出，绝不 pull。`Dockerfile.local` 用 `ARG BASE_IMAGE` 接受本地镜像，`docker build --pull=false` 只 COPY 教学文件形成新层。所有 run 再用 `--pull=never`。

真实闭环依次验证：挂错 volume target、不 publish 的主机失败、同网络容器 DNS 成功、loopback publish 成功、同 named volume 重建数据仍在、无卷文件随容器替换消失、bind 文件在脚本临时目录可见，最后逐项清理。

当前本地验证环境只确认 Docker CLI 28.4.0 可执行，daemon 未运行，因此本章交付**没有声称真实 daemon 路径通过**。默认离线模型和 shell 语法已验证；要获得真实容器证据，必须在前置满足时由学习者运行并保存输出。

## 十三、三个规定故障的诊断闭环

### 端口未发布

expected：容器网络内可达，主机 `127.0.0.1:18080` 失败。检查 logs 证明 8080 监听，再看 inspect 无 HostPort；修复为 loopback publish，重跑同一 curl。不要改应用端口来迁就缺失映射。

### volume 挂错路径

expected：当前容器在应用路径能读文件，inspect 显示 volume 去了另一路径，替换后数据消失。对照 Mounts.Destination 和日志数据目录；修正 target 后写唯一值，remove/new container 仍能读。

### 删除容器后数据丢失

先分类这是预期还是缺陷。临时缓存放可写层，替换后丢失是契约；工单数据库或附件若要求保留却无 volume，是设计缺陷。修复数据所有权与挂载，不能通过“永远不删除容器”掩盖。

每个闭环都要保存：预测、命令、inspect/log/文件或请求、首个可信失败、一个修复、原命令复跑和清理证据。

## 十四、安全边界与本章非目标

基础容器隔离不是生产安全结论。即使教学实验通过，仍未回答：

- 镜像漏洞、SBOM、签名和来源策略；
- 非 root 用户、只读根文件系统、capability 与 seccomp；
- secret 注入和轮换；
- CPU/内存/PID 限额；
- TLS、认证、主机防火墙和云网络；
- 日志驱动、监控与审计；
- volume 备份、恢复和加密；
- 多服务 Compose、滚动升级与 Kubernetes。

本章真实脚本因此不使用凭据、privileged、host network、Docker socket、主机系统 bind、全接口 publish 或公网镜像。安全的教学默认是“不做真实变更”，需要变更时再显式授权。

### Docker socket 为什么不能随便挂

能访问 daemon API 的容器通常拥有非常大的主机控制能力。把 `/var/run/docker.sock` 挂入不可信容器，不是普通文件共享。本章完全不需要也禁止这种做法。

## 十五、FactoryCare 独立构建任务

使用 [实验 worksheet](../../../labs/encyclopedia/ch.foundations.docker-basics/worksheet.md)：

1. 画出 image layers、container writable layer、volume/bind 和主机路径；
2. 预测 stop/start 与 remove/new 的数据差异；
3. 预测未 publish、loopback publish 和同网络 DNS；
4. 执行默认离线模型并记录 actual；
5. 用 inspect/log/文件三类证据解释错误 mount；
6. 写出逐项清理清单和明确保留的基础 image；
7. 若满足前置，再执行真实 daemon 脚本；否则写“未验证”，不得为了全绿临时 pull 未审查镜像；
8. 用 120 秒复述五条边界和一个失败反例。

验收要求：预期主机端口可达；named volume 数据跨容器重建存在；无卷数据按预期消失；同网络和主机 publish 不混淆；清理不影响其他资源。默认模型完成只算 T1 边界证据，真实 daemon 是额外运行证据，仍不是生产验收。

## 十六、常见反模式

### “容器 running，所以服务健康”

running 只说明主进程还活着。继续验证监听、请求和业务预言。

### “EXPOSE 了，所以 localhost 能访问”

EXPOSE 不创建主机映射。检查 publish。

### “restart 后数据还在，所以 volume 正确”

同一容器可写层仍在。必须 remove/new 验证。

### “容器内看见文件，所以持久化正确”

文件可能在可写层。对照 Mounts.Destination 和替换后读取。

### “数据库容器在 localhost”

每个容器的 localhost 是自己。使用同一用户定义网络的名称和目标容器端口。

### “端口冲突就发布到 0.0.0.0 的另一个端口”

地址范围和端口冲突是不同维度。教学默认 loopback，并选择空闲端口。

### “实验结束统一 prune”

prune 的影响超出本次资源。使用唯一名称逐项清理。

## 十七、AI 协作审查清单

AI 生成 Docker 命令时逐项问：

- image 是否已在本地，是否会隐式 pull；
- tag 是否可变，是否记录 digest；
- 命令是否包含登录、token 或私有 registry；
- publish 是否意外绑定所有接口；
- bind source 是否为系统目录、home 或 Docker socket；
- mount target 是否与应用数据目录完全一致；
- 删除命令是否 force、prune、通配或影响共享资源；
- 容器失败后是否先看 logs/inspect；
- 是否用 remove/new 而非 restart 验证持久化；
- 是否把模拟结果冒充真实 daemon 或生产验证。

任何远程 `curl | sh`、未审查 image pull、`--privileged` 和全局 prune 都应暂停，先明确影响、迁移与回滚。

## 十八、120 秒复述模板

> 镜像是不可变分层模板，容器是由镜像创建、以主进程为生命周期核心并拥有独立可写层的实例。stop/start 同一容器通常保留可写层，remove/new 不保留。named volume 由 Docker 管理并独立于容器，bind mount 直接映射主机路径、风险更大。应用监听容器端口不等于主机发布，教学用 127.0.0.1 的 host port→container port。用户定义 bridge 让同网容器按名称通信，容器 localhost 只指自己。反例是 volume 挂到 `/wrong`、应用写 `/expected`：当前看得到，重建后丢失；用 inspect、logs 和文件证据定位。

## 复习检查

1. 镜像层和容器可写层分别属于谁？
2. stop/start 与 remove/new 对可写层有何差异？
3. tag 和 digest 的身份语义为何不同？
4. EXPOSE 与 publish 分别做什么？
5. 为什么默认 publish 到所有接口有风险？
6. named volume 与 bind mount 的所有者和适用边界是什么？
7. mount 遮蔽与 mount 错路径如何区分？
8. 为什么同网容器通信通常不需要主机 publish？
9. 容器内 localhost 指谁？
10. inspect、logs 和文件证据各能证明什么？
11. 为什么 restart 不是持久化验收？
12. 教学脚本为何拒绝 pull、force 和 prune？

## 官方一手资料与范围声明

以下资料于 **2026-07-16** 从 Docker 官方文档复核：

- [What is an image?](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/) 与 [Understanding image layers](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/)：镜像不可变与分层模型；
- [What is a container?](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)：容器作为隔离进程及与 VM 的基础边界；
- [Storage](https://docs.docker.com/engine/storage/)、[Volumes](https://docs.docker.com/engine/storage/volumes/) 与 [Bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)：可写层、持久 volume、host bind 与安全注意；
- [Port publishing and mapping](https://docs.docker.com/engine/network/port-publishing/)：host/container 端口映射、默认接口范围与 loopback 绑定；
- [Bridge network driver](https://docs.docker.com/engine/network/drivers/bridge/)：用户定义 bridge、自动 DNS 与隔离；
- [docker container run](https://docs.docker.com/reference/cli/docker/container/run/) 与 [docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)：`--rm`、停止/删除和 volume 边界；
- [Docker Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/)：复核日用于确认官方现行 Engine 发布线；正文核心模型不依赖某个补丁版本。

Ruby runtime model、只允许 loopback/临时 bind 的限制、唯一名称和真实脚本步骤是本章**安全教学设计**，不是 Docker Engine 的完整实现。真实 daemon 因本机 daemon 未运行而未执行；生产镜像加固、Compose、Kubernetes、跨主机网络、备份恢复与安全验证均为明确非目标。
