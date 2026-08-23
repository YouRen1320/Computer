---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.linux-services
title: Linux 用户、文件、权限、进程与服务
responsibility: 在固定 Ubuntu Server 基线中管理用户、文件权限、进程、信号和 systemd 服务，区分可移植 Linux 原理与发行版实现，不教授网络诊断。
volume: '15'
order: 1
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.linux-services.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.cli-streams-exit-codes
version_surfaces:
- linux
- ubuntu-server-26.04
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Linux 用户、文件、权限、进程与服务”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-linux-identity-files
  - ops-linux-process-service
  covers_topics:
  - ops.linux-user-group
  - ops.file-mode
  - ops.ownership
  - ops.privilege-boundary
  - ops.process-signal
  - ops.systemd-unit
  - ops.service-journal
  - ops.resource-limit
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 在 Ubuntu Server 26.04 容器/虚拟机创建最小权限服务用户、部署 systemd 单元或等价受控夹具，并验证启动、停止、信号、日志和权限；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-linux-identity-files
  - ops-linux-process-service
  covers_topics:
  - ops.linux-user-group
  - ops.file-mode
  - ops.ownership
  - ops.privilege-boundary
  - ops.process-signal
  - ops.systemd-unit
  - ops.service-journal
  - ops.resource-limit
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: ubuntu-server-lab-permission-matrix-service-lifecycle-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“服务以 root 运行、目录所有者错误、ExecStart 路径不存在或 TERM 信号后进程未退出”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-linux-identity-files
  - ops-linux-process-service
  covers_topics:
  - ops.linux-user-group
  - ops.file-mode
  - ops.ownership
  - ops.privilege-boundary
  - ops.process-signal
  - ops.systemd-unit
  - ops.service-journal
  - ops.resource-limit
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Linux 用户、文件、权限、进程与服务

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《stdin、stdout、stderr、管道与退出码》](../../volume-00-computer-foundations/chapters/ch.foundations.cli-streams-exit-codes.md)：进程、管道、退出码和诊断命令依赖可靠 Shell 证据读取能力。
<!-- END GENERATED LEARNING PREREQUISITES -->

把程序放到服务器上“能运行一次”，与把它作为长期服务安全地运行，是两件完全不同的事。长期服务要回答：它以谁的身份运行、能读写哪些路径、由谁启动和停止、收到信号如何退出、失败后是否重启、日志到哪里、资源是否受限、出了问题先看什么证据。本章从零建立这一组心智模型，并把它落实为 FactoryCare Java API 的服务合同。

本章固定发行版练习基线为 Ubuntu Server 26.04 LTS。Linux 的用户、组、所有权、权限位、进程、信号等原理具有较强可移植性；用户管理命令、systemd 版本、sudo 实现和默认加固项属于发行版表面，必须按目标机器核验。官方发布说明显示 Ubuntu 26.04 LTS 于 2026 年 4 月发布并获得五年标准安全维护，但“LTS”不等于所有教程命令永远不变。

本章不教授 DNS、端口、TCP、TLS 与代理诊断，那是下一章的职责；也不把 macOS 上解析一个 unit 文件冒充 Ubuntu 中真实启动服务。你会先通过受控夹具验证合同，再在可用的 Ubuntu 虚拟机中补足真实生命周期证据。

## 1. 从“登录用户”到“服务身份”

Linux 用用户标识符 UID 和组标识符 GID参与授权判断。用户名和组名是便于人阅读的映射，内核最终使用数字标识。`id` 可以显示当前身份和附加组，`getent passwd factorycare` 与 `getent group factorycare` 可以通过系统名称服务查询账户记录。不要靠“我能在终端运行”推断服务也能访问同一文件，因为交互式用户与服务用户通常不同。

账户至少可分为三类：人类登录账户、系统服务账户和超级用户 root。人类账户需要登录、审计和个人权限；服务账户只代表某个应用，通常不应拥有交互式 shell，也不应与开发者共享；root 的 UID 为 0，可以绕过大量普通权限检查，因此不是解决权限错误的默认办法。最小权限的目标是：FactoryCare API 只获得启动所需的执行权限、读取只读配置的权限，以及写入明确数据目录的权限。

创建系统账户时，Ubuntu 常用 `adduser --system --group factorycare` 或等价的 `useradd --system` 方案。两套命令的选项和默认行为不同，执行前应查看目标系统手册。创建后必须核对结果，而不是只看命令退出码：

```bash
getent passwd factorycare
getent group factorycare
id factorycare
```

账户的 shell、home 目录和锁定状态都是合同的一部分。服务若不需要登录，应使用不可登录 shell；若需要固定工作目录，应由部署流程创建并赋予正确所有权。删除服务账户前还要先查找其拥有的文件和运行中的进程，否则会留下只有数字 UID 的孤儿文件，或把新账户意外映射到旧 UID 的资产。

### 1.1 主组、附加组与授权

每个进程有有效用户、有效主组和一组附加组。文件访问时，内核先判断进程用户是否等于文件所有者；若不是，再看进程是否属于文件组；仍不匹配才使用 other 权限。它不会把 owner、group、other 三组权限相加。一个常见误解是“文件组可写，所以所有者也能借用组写权限”；实际上一旦 owner 匹配，就只使用 owner 那一组三位。

把服务加入一个共享组可以授予目录访问权，但共享组越大，爆炸半径越大。不要为了省事把多个无关应用都加入同一 `app` 组。更稳妥的做法是按资源建立小组，并记录“谁因为什么业务需要属于该组”。修改组成员后，已存在的登录会话或进程未必立即获得新组集合；需要新会话或重启服务，并用 `id` 或 `/proc/<pid>/status` 核验运行进程的实际身份。

## 2. 文件所有权与权限位

`ls -l` 输出中的所有者、组和类似 `-rwxr-x---` 的字符串描述传统 Unix 权限。第一位是对象类型，后九位依次是 owner、group、other 的读、写、执行位。八进制把 `r=4`、`w=2`、`x=1` 相加，所以 `750` 表示所有者 `rwx`、组 `r-x`、其他人无权限；`640` 表示所有者读写、组只读、其他人无权限。

文件上的读表示读取内容，写表示修改内容，执行表示把它作为程序执行。目录语义不同：读表示列出目录项名称，写表示创建或删除目录项，执行表示穿越目录并访问已知名称。能读取文件仍要求路径上的每一级目录都可穿越。排查 `/opt/factorycare/api/config.yml: Permission denied` 时，不能只看最后一个文件；可以使用 `namei -l /opt/factorycare/api/config.yml` 逐级查看路径权限。

### 2.1 chmod 与 chown 的职责

`chmod` 修改权限位，`chown` 修改所有者和组，`chgrp` 只修改组。符号写法如 `chmod u=rwX,g=rX,o= path` 表意清晰，八进制适合固定部署合同。大写 `X` 只在对象为目录或原本已有执行位时添加执行权限，递归设置目录树时比无条件 `+x` 更安全。

不要把 `chmod -R 777` 当作排障方案。它既扩大访问范围，也会给普通数据文件增加执行位，而且掩盖真实身份和目录设计问题。正确过程是先写访问矩阵：哪个身份需要对哪个路径执行读、写、穿越中的哪一种操作；再设置所有权和最窄权限；最后分别以服务用户和非授权用户验证允许与拒绝。

一个可审查的部署布局可以是：程序和依赖位于 `/opt/factorycare/api`，由 root 部署且服务用户只读；持久数据位于 `/var/lib/factorycare`，由 `factorycare:factorycare` 拥有；日志若直接写文件则位于 `/var/log/factorycare`，但更推荐服务写标准输出/错误并交给日志系统；密钥位于单独受限路径，不能混在可公开静态资源中。

### 2.2 umask 与新文件默认权限

进程创建文件时先提出基础模式，再由 umask 屏蔽某些位。umask 不是最终权限值，也不会给基础模式原本没有的位“加权限”。例如常见普通文件基础模式为 `666`，umask `027` 后得到 `640`；目录基础模式为 `777`，得到 `750`。服务 unit 可用 `UMask=` 固定新文件策略，避免依赖启动者的交互式 shell 设置。

setuid、setgid、sticky bit 和 POSIX ACL 能表达更复杂规则。目录 setgid 可让新文件继承目录组，sticky bit 常见于共享临时目录，ACL 可为特定用户追加权限。本章只要求能识别这些机制存在；不要在没有访问矩阵和审计方案时叠加多层授权，因为 `ls -l` 之外还要查看 `getfacl`，排障复杂度会明显上升。

## 3. 权限边界与 sudo

`sudo` 是临时以另一身份执行经过策略允许的命令，不是“让所有问题消失”的前缀。生产服务器应把部署、服务控制、日志读取和业务数据访问分开授权。开发者可能获准重启 FactoryCare 服务，却不应自动获得任意 root shell；CI 发布账户可能获准替换特定目录中的制品，却不应读取运行时密钥。

Ubuntu 26.04 的 sudo 默认实现发生了版本相关变化，官方发布摘要说明默认使用 Rust 实现，并保留经典实现的兼容路径。这正说明教程不能只记二十年前的实现细节。稳定知识是策略边界、命令白名单、审计和最小权限；具体二进制、选项支持与配置迁移必须查看当前发行版文档并在测试环境验证。

不要直接编辑 sudoers 后祈祷语法正确；使用目标系统提供的安全编辑和校验工具，并保持一个可恢复的管理员会话。更不要把应用配置为 root 运行来规避目录权限。若服务确需绑定特权资源或执行有限管理动作，应优先使用能力分离、反向代理、socket 激活或单独的受限辅助进程，而不是把完整 root 权限交给整个 Java 进程。

### 3.1 机密不是普通配置

文件权限只能限制本机身份访问，不能弥补把密钥写入 Git、镜像层或日志的错误。环境变量也并非天然安全：它可能出现在进程环境、诊断转储或部署元数据中。运行身份、配置注入和密钥生命周期会在供应链章节继续展开。本章的最低要求是：服务用户能读取需要的机密；普通用户和静态文件服务不能读取；日志不得打印值；轮换后旧值失效。

## 4. 进程心智模型

程序是磁盘上的指令和数据，进程是程序的一次运行实例。一个进程有 PID、父进程 PPID、用户与组、当前目录、环境、打开文件、内存、线程和退出状态。相同 Java JAR 可以同时对应多个进程；不能只凭文件名判断“服务正在运行”。

`ps -ef` 给出快照，`ps -o pid,ppid,user,stat,etime,cmd -p <PID>` 可查看目标，`pgrep -a -u factorycare java` 可按身份和名称缩小范围。`top` 或 `htop` 用于动态观察，但截图不是充分证据；排障记录应保存时间、主机、命令、目标 PID 和关键输出。Linux `/proc/<PID>/` 暴露运行时信息，例如 `status`、`cmdline`、`environ` 和 `fd`，读取权限仍受身份限制。

前台与后台只是终端作业控制概念，不等于生产服务管理。`command &` 让 shell 不等待，关闭终端后进程可能收到挂断信号；`nohup` 也没有提供健康检查、重启策略、权限隔离和结构化日志。长期服务应交给服务管理器，而不是把一个后台命令当部署完成。

### 4.1 退出码与信号退出

进程正常结束会提供退出码，惯例中 0 表示命令声明的成功，非 0 表示不同失败。被信号终止时，shell 常显示与信号相关的状态，但显示编码不是跨所有 API 的唯一真理。服务管理器会同时记录结果、主退出码和信号。判断失败时，应读取管理器的结构化字段和应用日志，而不是只背“128+信号编号”。

僵尸进程已经退出但父进程尚未回收其状态；孤儿进程的父进程关系被重新接管。二者不是同一概念。PID 也会复用，因此延迟脚本只保存一个数字后盲目 `kill` 有误杀风险。服务控制应交给 systemd 的 cgroup 跟踪，并在手工操作前核对 PID、启动时间、命令和身份。

## 5. 信号与优雅退出

信号是内核向进程通知事件的一种机制。`SIGTERM` 表达“请有序终止”，应用可以注册处理逻辑；`SIGINT` 常由终端 Ctrl+C 触发；`SIGHUP` 的语义由应用约定，历史上与终端断开或重载有关；`SIGKILL` 无法捕获、忽略或清理，只应作为超时后的最后手段。

优雅退出不是打印一句日志。服务收到 TERM 后应停止接收新工作、允许进行中的有界请求完成、提交或回滚事务、关闭线程池与连接池、刷新必要缓冲，并在规定超时内以确定状态退出。若退出时间无上限，发布永远卡住；若超时过短，可能中断写操作。需要用负载下的真实关闭实验确定 `TimeoutStopSec=`，而不是随意填一个数。

`kill -TERM <PID>` 发送信号但不保证目标已退出。命令成功仅表示信号提交动作被接受。后续还要等待并核验进程消失、端口释放、请求停止、退出原因和数据一致性。`kill -0 <PID>` 只做存在/权限探测，也会受 PID 复用影响。systemd 管理的服务应优先使用 `systemctl stop`，让管理器按 unit 的 cgroup 和停止合同操作。

### 5.1 Java 服务的关闭边界

Spring Boot 通常通过 JVM shutdown hook 参与优雅关闭，但是否等待请求、等待多久、后台任务如何结束仍取决于应用和框架配置。不能因为日志出现“shutdown”就宣称零丢失。FactoryCare 要用测试请求、任务队列和数据库事务观察：停止期间新请求是否拒绝、已接收工单是否完整提交、后台同步是否留下可恢复游标。

若启动脚本写成 `sh -c 'java ...'` 且 shell 不使用 `exec`，服务管理器追踪的主进程可能是 shell，信号转发行为就会变复杂。简单启动脚本末尾应考虑 `exec java ...`，让 Java 成为主进程。systemd 的 `ExecStart=` 默认不是完整 shell 命令行；管道、重定向、变量展开不能照搬交互式 shell 直觉。

## 6. systemd 与 unit

Ubuntu Server 使用 systemd 管理系统和服务。unit 是声明式配置，`.service` 只是其中一种类型。服务文件通常分为 `[Unit]`、`[Service]`、`[Install]`：第一部分描述关系和说明，第二部分描述如何运行，第三部分描述启用时链接到哪个目标。理解每个字段的合同，比背一条长命令重要。

一个最小 FactoryCare unit 示例：

```ini
[Unit]
Description=FactoryCare API
After=network.target

[Service]
Type=simple
User=factorycare
Group=factorycare
WorkingDirectory=/opt/factorycare/api
ExecStart=/opt/factorycare/api/bin/start
ReadWritePaths=/var/lib/factorycare /var/log/factorycare
NoNewPrivileges=true
PrivateTmp=true
KillSignal=SIGTERM
TimeoutStopSec=20s
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

`User=` 和 `Group=` 固定身份；`WorkingDirectory=` 避免相对路径随启动环境漂移；`ExecStart=` 必须指向部署制品；`NoNewPrivileges=` 阻止进程及子进程通过执行新程序获得额外权限；`PrivateTmp=` 隔离临时目录；`ReadWritePaths=` 与更强的文件系统保护组合，描述允许写入的路径；`KillSignal=` 和停止超时明确退出协议。

### 6.1 Type 不是随便选

`Type=simple` 认为启动进程建立后服务已开始，`Type=exec` 会把执行主程序失败作为启动失败，`Type=notify` 要求应用通过通知协议报告就绪，`Type=forking` 面向传统自行后台化程序。现代前台 Java 进程不应为了“像守护进程”而自行 fork。启动完成也不等于业务就绪；数据库迁移、缓存预热和外部依赖可能仍未完成，健康与就绪合同要在后续章节建立。

`After=` 主要描述启动排序，不自动建立强依赖，也不证明被排序服务已经可用。`Wants=` 与 `Requires=` 描述不同强度的依赖关系，但仍不能替代应用层重试和健康验证。不要看到数据库 unit 排在前面就假定数据库一定接受连接。

### 6.2 enable、start 与 daemon-reload

`systemctl start factorycare-api` 启动当前服务；`enable` 配置未来开机时的启用关系，不等同于立即启动；`enable --now` 才组合两者。修改 unit 文件后，管理器需要 `systemctl daemon-reload` 重新加载定义，再重启或启动服务。只改文件不 reload，运行的仍可能是旧配置。

服务名、实际加载路径和 drop-in 覆盖应通过 `systemctl cat factorycare-api` 与 `systemctl show` 核验。手工打开某个 `/etc/systemd/system` 文件并不能证明它是生效版本，因为发行版 unit、别名和 drop-in 可能共同形成最终配置。`systemd-analyze verify` 可发现一部分语法和引用问题，但静态通过不代表程序一定能启动。

### 6.3 Restart 策略

`Restart=on-failure` 可以恢复偶发崩溃，但也可能形成快速重启循环，掩盖确定性配置错误并冲击依赖。需要配合重启间隔、速率限制和告警。计划内正常停止不应被当作故障立刻拉起。若服务每次启动都会执行非幂等迁移，自动重启会放大破坏，因此启动职责和迁移职责必须分开。

## 7. 日志与首个可信证据

服务写到标准输出和标准错误的内容可由 journal 收集。常用查询包括：

```bash
systemctl status factorycare-api --no-pager
systemctl show factorycare-api -p ActiveState -p SubState -p Result -p ExecMainStatus
journalctl -u factorycare-api --since "10 minutes ago" --no-pager
journalctl -u factorycare-api -b -n 200 --no-pager
```

`status` 适合快速摘要，不能代替完整日志；`show` 提供较稳定的机器可读属性；`journalctl` 按 unit、boot 和时间范围取事件。复制证据时要保存查询范围和时区。只截最后一行“failed”常会丢失更早的真正原因，例如 unit 用户不存在、工作目录无法进入、可执行文件缺失，或应用配置解析失败。

“首个可信证据”不是日志文件的第一行，而是沿执行阶段能最早证明哪条合同被破坏的证据。服务失败可按以下顺序诊断：unit 是否被正确加载；身份是否存在；工作目录和可执行文件是否可访问；进程是否真正创建；应用是否完成启动；停止时是否收到信号并退出。越早定位，越少在后续症状上浪费时间。

### 7.1 日志不是秘密仓库

journal 有访问控制和保留策略，但日志仍可能被运维、采集器和备份读取。禁止记录口令、完整 Token、私钥和敏感工单正文。结构化日志要带时间、级别、服务、环境、版本、关联 ID 和事件名，错误对象保留可诊断字段；敏感值应脱敏。日志轮转、磁盘上限和远程采集属于运行合同，不能等磁盘满后再补。

## 8. 资源限制

一个身份受限的进程仍可能耗尽 CPU、内存、文件描述符或进程数。传统 `ulimit` 面向当前 shell 及其子进程，systemd unit 可用 `LimitNOFILE=`、`TasksMax=`、`MemoryMax=`、`CPUQuota=` 等字段声明边界。具体字段的单位和行为必须查目标 systemd 手册，不能把网上任意版本的配置直接复制到生产。

资源限制既是保护也是容量假设。限制过高等于没有隔离，过低会让正常高峰失败。设定前要测量单请求内存、连接池、线程数、日志峰值和启动瞬时资源；设定后要注入压力并观察何种证据出现。进程被内存机制终止时，应用可能来不及写日志，应同时查看服务结果和内核日志。

文件描述符不仅是普通文件，还包括 socket、管道等。出现“Too many open files”时，盲目提高上限可能掩盖连接泄漏。先观察进程描述符数量与类型、增长趋势、连接池关闭路径，再决定修复泄漏还是调整容量。资源章节后面会深入性能和容量，本章只建立限制与证据边界。

## 9. 从制品到服务的部署顺序

可靠部署不是把 JAR 复制过去然后启动。建议把操作拆成可回滚步骤：确认目标主机和发行版；核验制品摘要与来源；确保服务账户存在；创建目录并设置所有权/模式；把新制品放入版本化目录；切换原子链接或发布指针；静态验证 unit；重新加载管理器；启动或重启；检查状态、日志和业务 smoke；失败时回到旧制品并保留证据。

程序目录最好由部署身份拥有、运行身份只读，从而让被攻陷的应用不能改写下次启动的代码。数据目录由服务身份写入，但数据库文件、上传文件和临时文件要进一步分区。配置与制品分离，版本信息应能从运行服务查询。用 `chown -R` 处理整个应用树虽方便，却可能把只读程序和密钥一起变成可写。

部署脚本每一步都应检查退出码，并在失败时停止。管道要理解 `pipefail`，变量要正确引用，目标路径要防止为空。可重复执行意味着“目标已存在”能收敛到正确状态，而不是重复创建用户时报错或每次追加同一配置。幂等不等于忽略所有错误；它要求把期望状态与实际状态比较。

### 9.1 权限矩阵

至少验证三种身份：root/部署者、`factorycare` 服务用户、普通非授权用户。至少覆盖程序、配置、数据、日志和密钥五类路径。结果应同时包含正向与反向断言，例如服务用户能执行启动器但不能改写它，能写数据目录但普通用户不能读取，部署者能替换版本但不能通过应用接口绕过审计。

可以用 `sudo -u factorycare -- test -r <path>`、`test -w`、`test -x` 做受控检查，但要记录正在验证的是文件还是目录语义。不要对真实生产数据执行破坏性写入来证明权限；创建专用探针文件并清理。反向测试很重要，因为“该用户能访问”没有证明“其他用户不能访问”。

## 10. 四类典型故障

### 10.1 服务以 root 运行

症状可能只是 `ps` 中 USER 为 root，服务甚至运行正常。首个可信证据是 unit 的有效 `User=`、`systemctl show -p User` 与运行进程 UID，而不是等安全事故发生。修复需要创建专用账户、划分目录所有权、补齐必要权限并重启；验证应证明正常功能仍通过且受限路径被拒绝。残余风险包括进程持有的 Linux capabilities、可写程序目录和过宽 sudo 规则。

### 10.2 目录所有者错误

应用报权限拒绝时，先确定失败操作和完整路径，再逐级检查目录穿越、文件模式、所有者、组、ACL 和挂载只读状态。不要直接 `777`。修复目标是访问矩阵，不是消除错误文本。修复后既跑成功路径，也用非授权身份重跑拒绝路径。

### 10.3 ExecStart 路径不存在

systemd 可能在应用日志产生前就失败。查看 `systemctl status`、journal 和 `systemctl cat`，核对绝对路径、文件存在、可执行权限、shebang 解释器以及架构。脚本文件存在但首行解释器不存在，同样会表现为执行失败。修复后运行静态 verify，再由服务管理器启动，不能只在当前 shell 手工运行。

### 10.4 TERM 后进程未退出

先确认信号发给了正确 unit/cgroup，再观察主进程和子进程。应用可能阻塞在非守护线程、未设超时的网络调用、锁或关闭钩子。扩大停止超时只能作为有证据的容量调整，不是默认修复。应建立自动测试：发起有界工作、请求停止、测量退出时长、检查业务一致性和残留进程。

## 11. 本章可运行资产

`examples/encyclopedia/ch.ops.linux-services/` 用纯 Python 模拟传统 owner/group/other 权限选择，帮助理解“匹配哪一组三位”，不模拟 ACL、capabilities 或内核。`labs/encyclopedia/ch.ops.linux-services/` 静态读取 unit 与文件系统合同，验证非 root 身份、绝对 `ExecStart`、工作目录、可写路径和若干加固字段。

公开练习故意只检查绝对路径，遗漏 root 身份与 `NoNewPrivileges`，所以 `verify.sh` 必须失败；你需要补齐检查。私有解答展示最小实现。绿灯只能证明这些受控断言通过，不能证明 systemd 已启动服务，更不能证明 Ubuntu 中的权限、journal、信号和 cgroup 行为。

推荐真实实验在一次性 Ubuntu Server 26.04 虚拟机完成。保存 `/etc/os-release`、`uname -a`、systemd 版本、unit 有效内容、服务身份、权限矩阵、启动/停止命令、journal 时间窗和退出状态。注入故障后先预测失败阶段，再执行；修复后必须重跑原命令，而不是换一个更容易通过的判据。

## 12. FactoryCare 服务合同

FactoryCare 的 Java API 拥有业务事实和公共 API。部署为 Linux 服务不会改变所有权：systemd 负责进程生命周期与资源边界，不应该在 unit 脚本里实现工单状态机；Python AI 服务若存在，应拥有独立账户和目录，不能共享 Java 数据库凭据；Vue、Flutter、uni-app 客户端不在服务器上以同一身份写业务文件。

建议为每个服务记录一张运行卡：服务名、制品摘要、运行用户/组、只读路径、可写路径、配置来源、密钥引用、启动命令、健康地址、优雅退出期限、资源上限、日志查询、依赖和回滚版本。运行卡不是替代代码和 unit，而是把跨文件合同集中供审查。任何字段变化都要经过测试与发布记录。

进程能够启动只说明生命周期第一关通过。完整验收还包括：非 root、只读程序目录、明确数据目录、日志可关联、TERM 有界退出、失败可诊断、重启策略不形成风暴、制品身份可追溯。网络连通、TLS、数据库恢复和 SLO 会在后续章节逐层加入，避免一次把所有运维问题混成“服务器坏了”。

## 13. 新手最容易混淆的判断

第一，`chmod 777` 能让当前错误消失，不代表权限设计正确；它往往证明边界被拆掉。第二，`systemctl enable` 不等于当前已经运行，`start` 也不等于开机自动启动。第三，`After=database.service` 不等于数据库就绪。第四，发送 TERM 不等于进程已退出。第五，`systemctl status` 的绿色状态不等于业务健康。第六，静态 unit 校验通过不等于真实主机验证完成。

第七，在终端以自己的账户运行成功，不等于服务账户能运行。第八，文件本身可读但父目录不可穿越时仍不能访问。第九，服务用户能写目录不代表只有它能写。第十，重启后恢复不证明根因消失；自动重启甚至可能隐藏持续崩溃。每个判断都要转成“对象、身份、操作、阶段、证据和判据”。

## 14. 学习与验收清单

概念复述时，你应能在两分钟内说明 UID/GID、owner/group/other 选择规则、目录执行位、进程与程序区别、TERM 与 KILL、systemd unit 三段、journal 和资源限制，并给出“用 root 解决权限问题”的越界反例。若只能背命令却不能预测结果，说明心智模型尚未建立。

独立构建时，先画权限矩阵，再创建服务账户与目录，写 unit，运行静态校验，启动服务，读取结构化状态，验证正反权限，发送 TERM，确认有界退出，注入四类故障并按阶段定位。每轮保存命令、退出码、时间和制品身份。清理实验环境前保留去敏证据。

诊断回答使用固定结构：现象是什么；失败位于 unit 加载、身份/文件、进程创建、应用启动、运行或停止哪个阶段；首个可信证据是什么；修复改动哪条合同；原验证如何重跑；还有什么未覆盖。这样的表达既适合真实事故，也比背诵零散面试题更能证明工程能力。

## 15. 已验证与未验证边界

本章随附资产已在当前 macOS 作者环境使用 Python 标准库执行：权限选择示例、unit 静态合同和私有解答应通过，公开练习应稳定失败。这些结果只证明夹具逻辑与预期红绿状态。它们没有启动 systemd，没有创建真实 Linux 用户，没有修改 `/opt` 或 `/var`，没有发送真实服务信号，也没有产生 journal/cgroup 证据。

Ubuntu Server 26.04 虚拟机实验在获得对应环境后执行；在保存发行版、systemd、unit、权限、日志和生命周期证据前，状态必须写“未验证”。容器通常不以完整 systemd 为 PID 1，普通应用容器也不是练习系统服务管理的等价环境；若使用容器，只能明确验证其中实际具备的部分。

## 16. 官方资料与版本入口

- Ubuntu 26.04 LTS 发布说明：<https://documentation.ubuntu.com/release-notes/26.04/>
- Ubuntu 26.04 LTS 用户摘要：<https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/>
- `systemd.service` 手册：<https://www.man7.org/linux/man-pages/man5/systemd.service.5.html>
- `systemctl` 手册：<https://www.man7.org/linux/man-pages/man1/systemctl.1.html>

阅读顺序应是先掌握可移植原理，再查目标发行版和本机 `man` 页，最后用真实证据验证。不要把第三方博客的某条命令、另一个发行版的默认目录，或作者 macOS 上的静态测试当成 Ubuntu 26.04 的运行事实。
