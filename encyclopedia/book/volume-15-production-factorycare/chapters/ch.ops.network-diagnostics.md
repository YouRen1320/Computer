---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.network-diagnostics
title: DNS、端口、代理、TCP、TLS 与网络诊断
responsibility: 按名称解析、路由、监听端口、TCP、TLS、代理和 HTTP 层次定位网络故障，优先收集证据而非反复重启服务。
volume: '15'
order: 2
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.network-diagnostics.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.linux-services
- ch.foundations.http-curl
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
  text: 在 120 秒内解释“DNS、端口、代理、TCP、TLS 与网络诊断”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-network-path
  - ops-tls-http-diagnosis
  covers_topics:
  - ops.dns-resolution
  - ops.socket-listener
  - ops.tcp-connectivity
  - ops.proxy-environment
  - ops.tls-certificate-chain
  - ops.sni-hostname
  - ops.http-upstream
  - ops.layered-network-diagnosis
  uses_capabilities:
  - ops.linux-service-network
  - foundation.shell-command-stream
  - foundation.network-transport
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“DNS、端口、代理、TCP、TLS 与网络诊断”构建可运行程序与测试：搭建 DNS/hosts、TLS 和反向代理故障矩阵，使用 ss、dig/getent、curl 与 openssl 逐层定位端口拒绝、证书和上游错误；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-network-path
  - ops-tls-http-diagnosis
  covers_topics:
  - ops.dns-resolution
  - ops.socket-listener
  - ops.tcp-connectivity
  - ops.proxy-environment
  - ops.tls-certificate-chain
  - ops.sni-hostname
  - ops.http-upstream
  - ops.layered-network-diagnosis
  uses_capabilities:
  - ops.linux-service-network
  - foundation.shell-command-stream
  - foundation.network-transport
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: layered-probe-runbook-packet-path-fixture-tls-chain-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“域名解析错误却重启应用、服务只监听 loopback、证书主机名不匹配或代理环境劫持请求”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-network-path
  - ops-tls-http-diagnosis
  covers_topics:
  - ops.dns-resolution
  - ops.socket-listener
  - ops.tcp-connectivity
  - ops.proxy-environment
  - ops.tls-certificate-chain
  - ops.sni-hostname
  - ops.http-upstream
  - ops.layered-network-diagnosis
  uses_capabilities:
  - ops.linux-service-network
  - foundation.shell-command-stream
  - foundation.network-transport
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# DNS、端口、代理、TCP、TLS 与网络诊断

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Linux 用户、文件、权限、进程与服务》](ch.ops.linux-services.md)：网络诊断需要能识别目标进程、服务状态、日志和权限。
- [《HTTP 报文、方法、状态码、Header、Body 与 curl》](../../volume-00-computer-foundations/chapters/ch.foundations.http-curl.md)：必须先能读取 HTTP 请求响应、状态码和 curl 传输证据。
<!-- END GENERATED LEARNING PREREQUISITES -->

用户说“接口访问不了”，可能是域名没有解析、解析到了错误地址、客户端走了意外代理、目标端口没人监听、防火墙丢包、TCP 被拒绝、TLS 证书不匹配、反向代理找不到上游，或应用已经返回了 HTTP 错误。它们会在浏览器里汇成相似的失败页面，却属于不同阶段。网络诊断的核心不是记更多重启命令，而是沿真实请求路径找到最早失败的合同。

本章以 Ubuntu Server 26.04 为命令基线，建立 DNS→目标地址与路由→监听 socket→TCP→TLS→HTTP→上游应用的分层模型。稳定原理跨 Linux 发行版适用；`ss`、`getent`、`resolvectl`、`dig`、`curl`、`openssl` 的具体版本与输出字段属于版本表面，应在目标主机读取手册。本章不修改业务代码、不教授 Nginx 配置细节，也不把禁用证书校验当修复。

## 1. 先画出一次请求的完整路径

假设用户访问 `https://api.factorycare.example/work-orders`。客户端先决定是否使用代理，再把主机名解析成一个或多个 IP，选择地址和路由，向目标 IP 的 443 端口建立 TCP 连接；随后进行 TLS 握手，验证证书链、有效期和主机名，并通过 SNI 告诉服务端希望访问哪个站点；最后发送 HTTP 请求。入口代理可能再解析或连接 Java API 上游，Java 又可能连接数据库。

“地址”至少包含协议、主机和端口。`https://` 暗含默认 443，但显式端口可以覆盖；`localhost`、`127.0.0.1`、`::1` 不是所有网卡；容器里的 localhost 只指当前容器。每跳都要写清观察点：从哪台主机、哪个网络命名空间、以什么代理环境、访问哪个名字和端口。服务端本机成功不能证明远端客户端成功，浏览器失败也不能证明服务没监听。

一个严谨故障记录至少包含：时间和时区、源主机/容器、目标 URL、期望 DNS 结果、实际解析地址、TCP 结果、TLS 证书与主机名结果、HTTP 状态与头、服务端监听和日志。不要只写“网络不通”。没有源与目标，就无法解释不同机器为何得到不同结果。

### 1.1 分层不是说所有系统严格七层

本章的层次是诊断顺序，不是要求你在事故中背 OSI 七层。上层依赖下层：DNS 未得到目标地址时，后面的 TCP/TLS/HTTP 失败只是派生症状；TCP 成功后 TLS 才有意义；TLS 成功后才分析 HTTP 状态。例外是你可以用已知 IP 绕过 DNS做对照，但必须保留原主机名用于 SNI 与 Host，且不能把对照成功写成 DNS 已修复。

## 2. DNS：名字如何变成地址

DNS 把域名映射为记录。A 常表示 IPv4，AAAA 表示 IPv6，CNAME 表示别名，其他记录承担不同职责。应用实际如何解析不仅取决于权威 DNS，还可能受 `/etc/hosts`、系统解析器、缓存、VPN、搜索域和容器 DNS影响。`dig` 直接查询 DNS很有用，`getent ahosts <name>` 更接近许多 Linux 应用经过名称服务切换配置后的结果，两者回答的问题不同。

先记录：

```bash
getent ahosts api.factorycare.example
dig api.factorycare.example A
dig api.factorycare.example AAAA
cat /etc/resolv.conf
```

在使用 systemd-resolved 的环境中，`/etc/resolv.conf` 可能只是 stub 或受管理链接，不能单凭文件内容推断最终服务器；应结合 `resolvectl status`。容器可能使用运行时注入的解析器。修改 `/etc/hosts` 可做局部实验，但它会覆盖正常路径并只影响特定环境，不能作为全局 DNS 修复证据。

### 2.1 TTL、缓存与传播

DNS 记录带 TTL，递归解析器和客户端可在时限内缓存结果。更改权威记录后，不是全世界瞬间一致。诊断要分别查询权威、递归和实际客户端路径，并保存服务器、记录值和 TTL。简单执行“清 DNS 缓存”可能改变一个观察点，却不解释其他客户端，也可能掩盖错误的权威记录。

负缓存会缓存“不存在”等结果。搜索域可能把短主机名补成意外完整域名。尾随点表示绝对域名。若 Java 配置写 `database`，本机、Compose 和 Kubernetes 可能给它完全不同含义。生产合同应使用在该运行环境中明确可解析的名字，不依赖开发者笔记本习惯。

### 2.2 IPv4 与 IPv6

一个名字可同时返回 A 和 AAAA。客户端地址选择、网络是否支持 IPv6、服务监听地址都会影响结果。看到 IPv4 curl 成功而普通请求失败时，要检查普通请求是否先选了 IPv6，而不是删除 AAAA 当万能修复。分别用 `curl -4`、`curl -6` 只能用于诊断差异，最终应修正地址、监听或网络合同。

DNS 成功只证明获得记录，不证明那个地址正确，也不证明可达。把测试域名解析到旧服务器时，`dig` 会成功，但业务仍可能错误。期望值来自部署和 DNS 配置的权威合同，而不是“有一个 IP 就算好”。

## 3. socket、监听地址与端口

服务端应用通过 socket 监听一个本地地址和端口。`127.0.0.1:8080` 只接受本机 IPv4 loopback 路径；`0.0.0.0:8080` 通常表示所有 IPv4 接口；`[::1]:8080` 是 IPv6 loopback；`[::]:8080` 的双栈行为受系统配置影响。监听所有接口不是自动安全，需要防火墙、反向代理和认证边界共同限制。

Ubuntu 上可用：

```bash
ss -ltnp
ss -ltnp 'sport = :8080'
```

`-l` 看监听，`-t` 看 TCP，`-n` 避免反向解析混淆，`-p` 尝试显示进程。读取其他用户进程信息可能需要权限。证据要包含地址，不要只看到“8080”就宣布对外可用。`127.0.0.1:8080` 在服务器本机 curl 成功，但远端到服务器网卡地址会失败，这是“服务只监听 loopback”的典型问题。

### 3.1 端口与进程所有权

端口号只是约定和配置，不识别业务。另一个进程占用 8080 时，端口“开着”但可能不是 FactoryCare。把 `ss` 的 PID/进程与 systemd unit、启动时间和制品版本关联。若应用启动日志说监听 8080，而实际进程已崩溃，旧日志不是当前证据。

反向代理通常监听 80/443，Java 只监听内网或 loopback 的 8080。用户不能直连 8080可能是设计正确；判断必须依据拓扑。不要为了排障把内部端口暴露到公网。下一章会详细配置代理，本章只把入口监听与上游监听分开观察。

## 4. TCP：能否建立传输连接

TCP 连接建立需要源到目标的路由、沿途策略允许、目标地址存在且端口有监听。连接被拒绝通常表示目标主机快速返回“该端口无监听/被主动拒绝”；超时可能是丢包、防火墙、错误路由、地址不可达或远端无响应。两者是线索，不是绝对根因，仍需结合源端、服务端和网络设备证据。

可以用 `nc -vz host port`、`curl --connect-timeout` 或 `openssl s_client` 的连接阶段做探测。`ping` 使用 ICMP，成功不证明 TCP 端口开放，失败也可能只是 ICMP 被禁。`telnet` 能建立 TCP但不验证 TLS 或 HTTP。工具选择要与要证明的合同一致。

### 4.1 路由与多网卡

`ip route get <IP>` 可显示 Linux 选择的路由、出口接口和源地址。服务器有公网、内网、VPN或容器桥接多个接口时，返回路径也可能不同。只看目标路由不够；不对称路由、策略路由和安全组可让请求到达却回不去。应用开发者至少要保存源/目标、接口和路由证据，再交给网络负责人，而不是只说“运维网络有问题”。

监听证据和客户端连接证据必须成对：服务端 `ss` 证明在哪监听，客户端探针证明从实际源能否到达。若服务端根本无监听，先修服务；若有正确监听但远端超时，再查主机防火墙、云安全策略、路由和中间设备。顺序可以减少无效改动。

### 4.2 TCP 成功不等于业务成功

客户端连到端口只证明三次握手，端口后的协议可能错误。把 HTTPS 发给纯 HTTP端口会在 TLS阶段失败，把 HTTP发给 SSH端口会收到不可理解内容。端口约定不能替代协议证据。记录 ALPN、TLS 和 HTTP 响应才能继续判断。

## 5. 代理环境：请求可能没有走你以为的路径

命令行和应用常读取 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY` 与 `NO_PROXY`，大小写支持和优先级可能因工具而异。代理可改变 DNS 解析位置、目标连接、TLS终止和认证。终端 curl 成功但 systemd 服务失败，可能因为交互式 shell 有代理变量而 unit 没有；反过来也可能是服务继承了不应存在的代理。

先做去敏检查：

```bash
env | grep -iE '^(http|https|all|no)_proxy='
curl -v --connect-timeout 5 https://api.factorycare.example/health
```

输出可能包含代理地址或凭据，保存前要脱敏。`NO_PROXY` 的域名、后缀、IP 和 CIDR支持并非所有客户端一致，不能假定浏览器、curl、Java 和 Python 完全同义。为每个运行时写测试，并在服务配置中显式声明，而不是依赖登录 shell。

### 5.1 对照实验

`curl --noproxy '*'` 可作为某些 curl 场景的直连对照，但不应永久绕过组织代理策略。对比“按默认环境”和“明确直连”的 DNS、连接地址、证书颁发者与响应头，能定位代理是否介入。若企业代理执行 TLS 检查，客户端信任链可能与公网不同；正确修复是安装经过批准的信任链和配置策略，不是 `-k`。

systemd unit 的环境与当前终端不同。用 `systemctl show <unit> -p Environment` 只能看到管理器掌握的一部分配置，敏感信息读取也受权限；还要检查 EnvironmentFile 和应用配置。不要把完整环境直接贴入工单，因为可能泄露密钥。

## 6. TLS：身份、机密性与完整性

TCP建立后，TLS客户端发送支持的协议、密码套件、SNI等，服务端选择参数并返回证书链。客户端验证链是否连接到受信任根、证书是否在有效期、是否允许服务器用途、主机名是否匹配 SAN，并完成密钥协商。任何一步失败都不能简化为“证书过期”。

常用诊断：

```bash
openssl s_client \
  -connect api.factorycare.example:443 \
  -servername api.factorycare.example \
  -showcerts </dev/null

curl -v https://api.factorycare.example/health
```

`-servername` 发送 SNI。共享同一 IP 的多站点依靠 SNI选择证书；遗漏它可能看到默认证书，得出错误结论。`openssl s_client` 输出很多信息，握手结束不自动等于验证成功，要查看 verify result 并使用明确 CA/主机名校验选项。不同 OpenSSL 版本的参数应查当前手册。

### 6.1 证书链

服务端通常发送叶子证书和必要中间证书，不发送客户端已信任的根。浏览器可能缓存中间证书，使配置错误在某台机器“碰巧成功”；干净客户端或 Java 信任库则失败。应在受控客户端验证服务器实际发送的链，而不是只打开浏览器看锁图标。

自签名证书不是天然错误，但客户端必须通过明确安全渠道信任对应根。把叶子证书随意加入每台机器、关闭验证或信任所有证书都会破坏轮换和身份边界。内部 CA 需要签发、分发、吊销和轮换流程。

### 6.2 主机名、SAN 与 SNI

现代客户端主要使用 Subject Alternative Name 判断主机名。访问 IP 时，证书必须包含相应 IP SAN；仅证书主题里写名称不能依赖。把域名临时解析到新 IP 做预发布验证时，应保留 URL 主机名和 SNI，例如 curl 的 `--resolve` 可以把指定主机端口映射到测试 IP，同时继续正确验证主机名。

证书主机名不匹配时，修改 `/etc/hosts` 可能改变连接地址，却不会改变证书允许的身份。正确方案是使用证书覆盖的域名或重新签发正确证书。`curl -k`/`--insecure` 只能在明确隔离的诊断实验中证明“若跳过验证，后续协议可能工作”，绝不能作为修复或成功判据。

### 6.3 时间与有效期

客户端时钟错误可把有效证书判断为未生效或已过期。比较证书 `notBefore`/`notAfter`、当前 UTC时间和时间同步状态。证书轮换要在旧证书过期前部署并验证所有入口，不能只看文件已替换；进程可能尚未 reload，负载均衡后也可能有部分节点仍使用旧证书。

## 7. HTTP 与反向代理上游

TLS成功后，HTTP状态才有意义。`2xx` 表示请求按该接口语义成功，`3xx` 表示重定向，`4xx` 通常表示客户端请求、认证或授权问题，`5xx` 表示服务端或网关失败。它们不是绝对责任归属，但比“页面打不开”精确。保存状态、响应头、请求 ID 和经过脱敏的响应体。

`curl -i` 显示头，`-v` 显示连接过程，`--fail-with-body` 可让 HTTP错误影响退出状态同时保留响应体。不要默认 `curl` 退出码 0 就表示 HTTP 200；普通 curl 能成功完成一次 500 响应的传输。HTTP基础章节已建立这一点，本章把它放回网络路径。

### 7.1 502、503、504 的区别

反向代理常用 502 表示收到无效上游响应或连接问题，503 表示暂不可用，504 表示等待上游超时；具体实现仍以代理文档和配置为准。入口返回 502时，公网 DNS、TCP和TLS可能全部正常，故障位于代理到上游的新一跳。要从代理所在网络命名空间探测 Java 地址和端口，并关联代理错误日志与 Java日志。

浏览器直接访问 Java 上游成功，也不能证明代理路径正确。Host 头、路径前缀、协议、端口、容器 DNS和健康检查可能不同。诊断要重建代理真实请求，而不是换一条路径后宣布恢复。

### 7.2 Host、转发头与身份

HTTP Host 决定虚拟主机，代理还可能设置 `X-Forwarded-For`、`X-Forwarded-Proto` 或标准 Forwarded。应用只能信任来自已批准代理的转发头，否则客户端可伪造来源和协议。转发头错误可能造成重定向循环、错误绝对链接或安全判断失效，但不是 TLS本身的问题。

关联 ID应从入口传播到 Java API及下游日志，帮助证明一次请求经过哪些组件。没有关联 ID时也可按时间、客户端地址和路径近似关联，但可信度更低。不要把时间相近当唯一因果证据。

## 8. 固定的分层诊断流程

第一步冻结问题描述：谁、何时、从哪里访问哪个精确 URL，期望什么，实际是什么。第二步确认变更与范围：所有用户还是一个网络、所有节点还是一个节点、IPv4还是IPv6、代理内外是否不同。第三步从实际客户端开始按层探测。第四步在最早失败层寻找服务端或配置证据。第五步只改一条明确合同。第六步重跑同一探针，并补跑上下层 smoke。

可以使用下表形成运行手册：

| 层 | 要证明的问题 | 常见证据 | 不能证明 |
|---|---|---|---|
| DNS | 名字在该客户端解析为何值 | `getent`、`dig`、解析器状态 | 地址可达 |
| 路由/监听 | 包走哪、服务在哪个地址监听 | `ip route get`、`ss -ltnp` | TCP从远端成功 |
| TCP | 源到目标端口能建立连接 | `nc`、curl connect timing | TLS身份正确 |
| TLS | 链、时间、SAN、SNI通过 | `openssl s_client`、curl verbose | HTTP业务成功 |
| HTTP | 状态、头、路径和上游结果 | curl、代理与应用日志 | 数据逻辑一定正确 |

当 DNS失败时，不应先重启 Java；当端口无人监听时，不应先替换证书；当证书主机名错误时，不应调数据库；当 HTTP 401 时，TCP和TLS已经完成，应该检查认证合同。层次的价值是把症状变成有限假设。

### 8.1 成功、边界与失败样本

每个实验至少保留三类样本。成功样本证明完整路径；边界样本如不存在路径得到预期 404，证明服务可达但请求语义不同；失败样本注入一个已知问题并捕获最早证据。只有成功样本容易让诊断脚本把所有异常都归为“不通”。

超时必须显式设置。无上限等待会拖住 CI和事故排查，太短则把正常延迟误判为故障。分别设置 DNS、连接、TLS/总请求超时并记录值。重试会改变观察结果；首次诊断可先关闭隐式重试或显示每次尝试，避免一次成功掩盖前几次失败。

## 9. 四个典型故障的证据链

### 9.1 域名错误却不断重启应用

若客户端把 `api.factorycare.example` 解析到旧 IP，应用重启不会改变 DNS。首个可信证据是实际客户端解析结果与部署期望不符。修复权威记录或客户端覆盖后，应在 TTL与多个观察点验证，并重跑原 URL。残余风险包括缓存未过期、IPv6记录仍旧、split-horizon DNS内外不一致。

### 9.2 服务只监听 loopback

服务器本机 `curl http://127.0.0.1:8080` 成功，远端连接服务器地址失败。`ss` 显示 `127.0.0.1:8080` 是首个关键证据。若设计是由同机 Nginx代理，loopback可能正确，应修代理上游而非对外暴露；若确需远端直连，才在安全策略允许下调整监听并验证防火墙与认证。

### 9.3 证书主机名不匹配

TCP成功、TLS返回证书，但 SAN不含请求域名。首个可信证据是客户端主机名校验错误及证书 SAN。修复是为正确名称签发/部署证书或使用正确 URL，不是永久关闭校验。重跑应使用默认严格客户端，并检查所有负载均衡节点。

### 9.4 代理环境劫持请求

默认 curl连接企业代理或未知本机端口，明确直连路径结果不同。证据包括代理环境、verbose 输出中的连接目标和代理响应头。修复应明确服务是否允许代理、正确配置 NO_PROXY或删除意外注入，并在 systemd真实环境验证。不要把代理凭据写进日志。

## 10. FactoryCare 拓扑中的责任边界

外部客户端通过 HTTPS入口访问 Java API；Java拥有工单、设备、权限和状态机事实。Nginx或其他代理负责TLS终止和转发，不应偷偷重写业务状态。Python AI服务只提供派生建议，若 Java调用它，要把该内部跳作为独立 DNS/TCP/HTTP路径诊断。Vue、Flutter和uni-app观察到的错误要保留客户端环境与请求 ID。

建议定义三类健康端点：进程活性只回答进程是否能响应；就绪状态回答是否可以接收流量；诊断依赖状态用于内部观测但不能泄露密钥。入口代理的健康检查地址、Host、协议和超时必须与合同一致。健康合同默认只接受约定的 `2xx`（必要时精确到 `200`/`204`）；`3xx` 应分类为普通跳转、跨主机、自循环或缺少 `Location`，并只保存安全摘要，不得因跳到登录页而误报健康。健康检查成功不等于所有业务接口正确，只证明声明的窄条件。

跨服务调用要规定超时、重试和幂等。网络失败后客户端不知道服务端是否已处理请求，盲目重试写操作可能重复创建工单。使用幂等键或可查询结果，而不是把网络重试当业务正确性。这个边界说明网络诊断与领域逻辑相邻但不能互相替代。

## 11. 本章可运行资产

示例资产把 DNS、TCP、TLS、HTTP探针结果映射为最早失败层。实验资产只在本机 loopback 启动 Python HTTP服务，真实调用系统解析器、TCP和HTTP，证明健康路径与 503路径不会混淆。公开练习故意从 HTTP向下倒序判断，因此多个层同时失败时错误报告最上层症状；私有解答按依赖顺序修复。

这些资产没有建立TLS，也没有修改DNS、hosts、代理、防火墙或Ubuntu路由；本地 `localhost` 结果不能证明生产网络。完整实验需要隔离的 Ubuntu Server 26.04 虚拟机或经授权测试环境，搭建可撤销的DNS/hosts、TLS和反向代理故障矩阵。任何真实网络变更前都应写影响、回滚和授权范围。

实验记录包含：`/etc/os-release`、工具版本、源/目标、解析输出、监听、连接、证书摘要与SAN、HTTP状态、代理环境脱敏摘要、日志时间窗、注入、修复和同一探针重跑。若某层没有执行，就写未验证，不能由下游或本地对照推断。

## 12. 新手常见反模式

“先重启再说”会毁掉进程状态和短期日志，且没有缩小假设。“ping通所以网络没问题”混淆ICMP与目标TCP端口。“端口开着所以接口正常”忽略TLS和HTTP。“curl -k成功所以证书修好了”恰好证明严格验证仍被绕过。“服务器本机成功所以用户应该成功”忽略源路径。“改 hosts 成功所以DNS已恢复”只证明局部覆盖。

另一个反模式是一次改DNS、证书、代理和应用配置，最终不知道哪条改动有效，也难以回滚。每次只修一条被证据否定的合同，保存前后结果。事故紧急也要保留最少证据，否则下次只能重复猜测。

不要直接公开 `curl -v`、证书私钥路径、代理凭据、Authorization头和完整内部域名清单。证据要去敏但保持结构，例如保留证书指纹、颁发者、SAN类别和时间，Token只记录存在与哈希标识。去敏后的记录仍要受访问控制。

## 13. 学习验收

两分钟复述应从用户URL一路说到上游应用，解释DNS记录不等于可达、监听地址不等于远端可连、TCP成功不等于TLS身份正确、TLS成功不等于HTTP成功，并举“DNS错却重启Java”作为越界反例。你还要能说明代理为何改变路径、SNI与Host为何不能随意丢。

独立实验应至少注入：错误解析、loopback监听、无监听端口、TLS主机名错误、代理介入和上游503。对每项先预测最早失败层，用对应命令捕获证据，修复后重跑原探针，并跑完整路径。仅在浏览器刷新成功不能过关。

诊断回答采用固定格式：实际源和目标；最早失败层；首个可信证据；为什么更高层现象是派生症状；最小修复；同一探针重跑；残余风险与未验证层。这样既服务真实工作，也能在面试中展示可复现的工程判断。

## 14. 已验证与未验证边界

当前实际验证仅包括作者机 loopback 的系统名称解析、TCP和HTTP受控服务器，以及纯函数的层次分类。它证明示例、实验和私有解答绿灯，公开练习稳定红灯；不证明Ubuntu命令输出、外部DNS、IPv6、代理、TLS链、Nginx上游、防火墙或生产FactoryCare可用。

Ubuntu Server 26.04和真实TLS故障矩阵必须在环境可用且获得授权后验证。生产网络、证书和DNS都有外部影响，本教材不会自动执行变更。任何未保存目标环境证据的结论都标为“教材说明”或“待实机验证”，不能写成已完成运维验收。

## 15. 官方资料入口

- Ubuntu 26.04 LTS发布说明：<https://documentation.ubuntu.com/release-notes/26.04/>
- curl官方文档：<https://curl.se/docs/>
- OpenSSL官方文档：<https://docs.openssl.org/>
- systemd-resolved与resolvectl应优先读取目标Ubuntu上的 `man systemd-resolved`、`man resolvectl`。

工具帮助只能告诉你选项，不能替你定义期望拓扑。先从部署配置、DNS权威记录、证书和服务合同得到“应该是什么”，再用命令观察“实际是什么”，二者差异才是可操作的故障证据。
