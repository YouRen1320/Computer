---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.nginx-tls
title: Nginx、TLS、反向代理与静态资源
responsibility: 使用 Nginx 终止 TLS、托管版本化静态资源并代理 API，正确传递客户端和关联信息，不承担应用授权。
volume: '15'
order: 5
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.nginx-tls.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.compose-services
version_surfaces:
- linux
- ubuntu-server-26.04
- docker
- docker-compose
- nginx
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Nginx、TLS、反向代理与静态资源”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-nginx-proxy
  - ops-nginx-tls-static
  covers_topics:
  - ops.nginx-server-location
  - ops.reverse-proxy
  - ops.forwarded-header
  - ops.upstream-timeout
  - ops.tls-termination
  - ops.certificate-renewal
  - ops.static-cache-header
  - ops.spa-fallback
  uses_capabilities:
  - ops.linux-service-network
  - foundation.http-message
  - foundation.docker-runtime
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 配置 TLS Nginx 为 Vue 静态站点与 Java API 反代，验证 Host/X-Forwarded-*、超时、缓存、SPA fallback
    和证书链；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-nginx-proxy
  - ops-nginx-tls-static
  covers_topics:
  - ops.nginx-server-location
  - ops.reverse-proxy
  - ops.forwarded-header
  - ops.upstream-timeout
  - ops.tls-termination
  - ops.certificate-renewal
  - ops.static-cache-header
  - ops.spa-fallback
  uses_capabilities:
  - ops.linux-service-network
  - foundation.http-message
  - foundation.docker-runtime
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: nginx-config-test-tls-probe-proxy-header-integration
- id: diagnose
  kind: fault-diagnosis
  text: 面对“信任任意客户端 X-Forwarded-For、API 路径被 SPA fallback 吞掉、证书链不全或敏感响应被长期缓存”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-nginx-proxy
  - ops-nginx-tls-static
  covers_topics:
  - ops.nginx-server-location
  - ops.reverse-proxy
  - ops.forwarded-header
  - ops.upstream-timeout
  - ops.tls-termination
  - ops.certificate-renewal
  - ops.static-cache-header
  - ops.spa-fallback
  uses_capabilities:
  - ops.linux-service-network
  - foundation.http-message
  - foundation.docker-runtime
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Nginx、TLS、反向代理与静态资源

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Compose 多服务、配置、健康检查与依赖》](ch.ops.compose-services.md)：Nginx 需要在已验证多服务网络和健康合同上代理上游。
<!-- END GENERATED LEARNING PREREQUISITES -->

Nginx位于客户端与FactoryCare服务之间：选择虚拟主机和location、终止TLS、托管Vue静态文件、把/api/请求转发给Java、设置超时与必要代理头。它不拥有工单权限和业务状态机，也不能因为位于入口就替Java做最终授权。代理层提供传输与路由证据，Java仍从可信认证材料建立用户并检查租户、资源和动作。

本章把配置意图、语法验证、TLS密码学验证和端到端代理行为分层。当前机器没有nginx命令，Docker daemon也离线；资产只做Python静态源码审计和TLS清单一致性检查。fullchain与hostname均为声明fixture，不是证书。任何nginx -t、openssl握手、真实转发头和超时结果都标UNVERIFIED。

## 1. 一次请求如何进入Nginx

客户端先做DNS、TCP与TLS，再发送HTTP请求。Nginx按监听地址/端口和Host选择server，随后按URI选择location。选错server或location会在应用之前产生错误，因此第一证据是Nginx访问/错误日志和最终配置，而不是Java日志。

Nginx官方Request processing文档说明default server是listen端口的属性；Host没有匹配时进入该端口默认server。生产应显式定义default_server，对未知Host拒绝或返回受控响应，避免落入第一个业务站点。

server_name用于虚拟主机匹配，不等于TLS证书验证。TLS握手中的SNI与证书SAN决定主机名是否可信；HTTP Host再决定请求路由。两层都要测试。

反向代理只是网络路径。若Java直接发布到公网，攻击者可绕过Nginx的TLS、头规范和限流。因此Compose只让proxy发布宿主端口，api留在edge内部网络。

## 2. location匹配

location可用精确匹配=、普通前缀、^~前缀和正则。官方文档说明先找最具体前缀，再按规则评估正则；顺序与类型共同决定结果。不能只因/api/块写在/之前就假设一定命中。

本章使用location ^~ /api/隔离API，阻止后续正则把它当静态文件；location ^~ /assets/处理版本化资源；location = /index.html单独设置短缓存；最后location /才做SPA fallback。

URI匹配不含查询参数。/api/orders?status=OPEN仍按/api/路径匹配。访问日志应记录request_uri以保留查询，但敏感查询参数需脱敏或避免使用。

配置审查制作路径矩阵：/api/orders、/api/unknown、/assets/app.hash.js、/missing-route、/index.html和/。每个路径写预期location、上游/文件、状态与缓存头。

## 3. proxy_pass与URI

proxy_pass可以带URI或不带。Nginx官方proxy模块文档说明：若proxy_pass带URI，匹配location的规范化前缀会被替换；不带URI通常把请求URI传给上游。尾部斜杠差异常导致/api/foo变/foo或/api/foo。

如果Java Controller本来映射/api/orders，本章使用proxy_pass http://factorycare_api;不带URI以保留/api/。若Java映射/orders，可以显式用proxy_pass http://factorycare_api/并通过测试确认改写。不要凭印象选择。

正则location、rewrite和变量proxy_pass有额外规则，应以官方文档和nginx -T最终配置验证。越复杂的改写越难诊断，API路径契约应尽量简单。

端到端测试让Java回显接收的path、Host、scheme和request ID，在受控环境断言；静态查到字符串不能证明真实URI。

## 4. Host与关联信息

默认代理Host行为可能与客户端期望不同，因此显式proxy_set_header Host $host，让Java知道经过验证的站点名。若上游需要原始端口，可设计X-Forwarded-Host/Port，但字段集合与Java框架配置要一致。

X-Request-ID应由可信入口生成或验证长度/字符后规范化。Nginx内置$request_id可传给Java；Java日志继续同一ID。不要接受任意巨大客户端ID进入日志，也不要把它当认证凭据。

关联ID用于追踪，不保证幂等。关闭工单等写动作仍需业务idempotency key、认证和事务。

Host、X-Forwarded-*都是输入数据。Java只有在请求确实来自受信代理网络时才使用，否则客户端可直连并伪造https或来源IP。

## 5. X-Forwarded-For信任边界

客户端可自行发送X-Forwarded-For。若Nginx信任0.0.0.0/0，攻击者能伪造IP，破坏审计、限流和地域策略。ngx_http_realip_module通过set_real_ip_from列出已知代理地址，再从指定header恢复来源。

官方realip文档说明set_real_ip_from定义“已知会发送正确替换地址”的可信地址；real_ip_recursive on时，从链中选择最后一个非可信地址。这个模块需要在构建中启用，真实nginx -V要确认。

本章fixture表示Nginx位于受信172.16.0.0/12 ingress之后。realip完成后，向Java发送规范化X-Forwarded-For $remote_addr，而不是原样转发$http_x_forwarded_for。若Nginx本身是第一公网边缘，则不需要信任客户端XFF，直接以连接地址重建。

不同云负载均衡器的代理网段会变化，可信CIDR应由平台配置与自动测试维护。不能复制教程私网段到生产。

## 6. X-Forwarded-Proto与安全链接

Nginx终止TLS后，Java到Nginx的内部连接可能是HTTP。proxy_set_header X-Forwarded-Proto $scheme让Java生成https外链、设置安全cookie并判断原始方案。

Java/Spring不能对所有来源无条件信任forwarded headers。只从反向代理网络接收，配置框架的forward-header策略，并做直接访问拒绝测试。否则攻击者传X-Forwarded-Proto:http/https会影响重定向和安全判断。

代理头不是用户身份。认证来自session/JWT等协议，资源授权来自Java。IP只能作为辅助风险信号，不应成为唯一管理员凭据。

如果还有云LB→Nginx→Java多跳，定义每跳谁覆盖、谁追加和谁解析。保存路径图与可信代理集合。

## 7. 上游连接与超时

proxy_connect_timeout限制与上游建立连接，proxy_send_timeout限制向上游两次写之间，proxy_read_timeout限制从上游两次读之间。Nginx官方明确proxy_read_timeout不是整个响应总时长，而是连续读取之间的等待。

超时太短会截断合法慢请求，太长会耗连接。按API类型设预算：普通CRUD较短，导出或流式端点单独location。Java自身还需数据库和外部调用超时，形成从外到内递减预算。

504通常表示上游超时，502常见于连接/协议失败；具体看error log。不要用SPA index覆盖这些错误，否则前端收到200 HTML再报JSON解析错，首个真实失败被隐藏。

流式响应可能还需proxy_buffering off、合适read timeout与客户端断连传播；这些必须在专门流端点实测，本章fixture不声称支持SSE。

## 8. 代理缓冲与请求体

Nginx默认可能缓冲请求/响应，有助于隔离慢客户端，却会影响流式延迟与磁盘临时文件。上传大小受client_max_body_size等限制，Java限制也要一致。

不要全局关闭缓冲。按端点性质配置：普通JSON保留合理默认，SSE明确关闭响应缓冲，上传设计大小、超时、临时目录与病毒扫描。只读Nginx容器需为必要temp目录提供tmpfs。

请求体限制拒绝过大输入，但不能代替Java字段校验。Nginx看到的是字节与HTTP，Java理解工单语义。

真实慢客户端、分块上传和断连测试需要运行Nginx。静态配置审计只能确认指令存在。

## 9. TLS终止

TLS终止意味着Nginx持有证书和私钥，对外完成握手，内部按拓扑使用HTTP或再次TLS。证书必须覆盖server_name，处于有效期，链可由客户端构建，私钥匹配且权限最小。

Nginx官方HTTPS文档当前默认协议示例涉及TLSv1.2/TLSv1.3；实际密码套件、安全级别和客户端兼容应依据当前平台基线。不要从旧博客复制已弃用协议。

fixture写ssl_protocols TLSv1.2 TLSv1.3与fullchain路径，只证明文本意图。tls-inventory JSON只是合成清单，未包含PEM，不能证明SAN、有效期、签名、key match或链。

生产验证用nginx -t、openssl x509检查、openssl s_client带-servername检查链与握手，再从真实客户端curl校验。不能加-k绕过验证后声称TLS成功。

## 10. 证书链

服务器通常发送叶证书和必要中间证书，不发送根。Nginx官方HTTPS文档说明合并文件中服务器证书在前，后接chain bundle；顺序错误可能导致启动或匹配错误。

浏览器缓存中间证书可能让缺链配置“在我电脑能开”，新设备却失败。使用openssl s_client观察服务实际发送的Certificate chain，而不是只检查本地文件名。

ssl_certificate应指向fullchain，ssl_certificate_key指向私钥。私钥绝不进入镜像公开层、Git或日志；以运行时secret只读挂载，并限制Nginx用户读取。

多证书/SNI配置要对每个hostname测试。默认server返回的证书也需考虑未知SNI行为，不能让内部名称泄露。

## 11. 续期与安全reload

证书会过期。Certbot官方文档说明certbot renew检查接近到期证书并尝试续期，多数安装包含自动续期；具体阈值和服务机制随版本变化。生产要监控剩余天数，不只相信timer存在。

续期流程：挑战成功→新证书写入→校验文件与key→nginx -t→优雅reload→外部握手验证。任何一步失败保留旧可用配置并告警。先reload再测试可能造成中断。

nginx reload由master读取新配置，成功后新worker接流量、旧worker优雅退出。仍要观察日志和进程；收到reload命令退出0不等于外部已使用新证书。

使用certbot renew --dry-run或对应CA staging做定期演练，避免到期当天才发现DNS、端口或权限变化。本章未安装Certbot，也未实际续期。

## 12. Vue静态资源

Vue构建通常产生index.html与带content hash的JS/CSS。哈希assets内容变则URL变，可设置Cache-Control: public,max-age=31536000,immutable；文件不存在应404，不回SPA。

index.html引用最新hash，因此应no-cache或短缓存并重新验证。若index长期immutable，发布后用户仍引用旧assets；旧assets又若立即删除会产生白屏。发布策略保留一段旧hash资源。

source map可能泄露源码与内部路径，应按调试政策决定是否发布，不能因在dist就自动公开。运行时公开配置也要明确不含秘密。

Nginx静态服务只负责文件与缓存头，不修复前端XSS、CSP或依赖风险。安全header要按应用实际资源测试。

## 13. SPA fallback与API隔离

Vue history路由访问/orders/7时磁盘无该文件，需要location /的try_files $uri $uri/ /index.html回退。它只适用于前端路由。

若/api/也落入location /，Java 404、502甚至拼写错误可能返回200 index.html。前端随后报Unexpected token <，排错人员误查JSON。显式^~ /api/且API块无try_files可阻止。

API应原样保留上游状态、正文和Content-Type。proxy_intercept_errors off表达不由静态错误页改写；若使用自定义错误页，仍不能把业务JSON替换成HTML 200。

测试矩阵含Java 200/400/401/403/404/500和上游断开502/超时504，逐一验证代理状态与body类型。fixture未运行，矩阵UNVERIFIED。

## 14. 缓存策略

缓存是按资源风险分类的合同。哈希静态资源可长期immutable；index短缓存；API与认证/个人信息响应默认no-store，除非经过专门缓存设计。

add_header的继承与状态码行为有细节，always参数影响非成功响应，当前语义以官方headers模块为准。不要在server级全局加长期Cache-Control，它可能落到API错误或敏感数据。

代理缓存若启用，还需cache key、Authorization/Cookie、Vary、失效和跨租户隔离。错误配置可能把A用户工单返回给B。FactoryCare本章不启用API proxy_cache。

浏览器、CDN和Nginx是不同缓存层。curl -I只能观察响应头，不能证明所有中间层行为；端到端发布测试要含第二次请求与版本切换。

## 15. 配置验证与发布

第一步生成最终配置，确认include与环境模板。第二步nginx -t检查语法、引用文件和部分证书/key关系。第三步reload，观察error log。第四步外部curl/openssl验证DNS、TLS、头、缓存、API与SPA。

nginx -T可打印合并配置，但可能暴露路径或值，证据需脱敏。容器内命令必须针对实际镜像digest。只在宿主编辑一份未挂载配置并运行本地nginx -t不能证明容器使用它。

发布要可回滚：保留上一配置和证书引用；test失败不reload；外部smoke失败恢复上一制品。不要ssh进去手工改且不回Git。

本机nginx命令不存在，所以本章只完成Python静态策略。STATIC PASS不能写成nginx-config-test通过。

## 16. Java业务事实边界

Nginx可校验TLS、路由与请求大小，可能执行粗粒度认证子请求，但最终FactoryCare权限仍在Java。工单7是否属于当前租户、状态能否关闭、幂等是否重复，全由Java加载事实并在事务检查。

Java日志接受Nginx生成的request ID和规范化来源信息，但用户身份从受验证令牌建立。即使Nginx漏配某header，Java不能默认管理员。

Nginx返回502表示上游路径失败，不应创建或回滚工单。若Java已提交但客户端断线，调用方以业务幂等键查询结果，不从代理错误猜状态。

将代理和业务错误分层：Nginx access/error日志证明入口与上游；Java日志/数据库证明领域动作。两者用关联ID连接。

## 17. 故障矩阵

|故障|最早层|首个可信证据|修复|
|---|---|---|---|
|未知Host进入业务站点|server选择|access log/server_name|显式default_server拒绝|
|/api被index吞|location|路径矩阵、Content-Type|^~ /api/独立块|
|proxy_pass斜杠改错路径|代理URI|Java回显path|按官方替换规则固定并测试|
|信任0.0.0.0/0 XFF|realip|最终配置与伪造请求|只信平台代理CIDR并规范化|
|Proto丢失|代理头|Java生成http链接|传$scheme且Java仅信代理|
|API 500被缓存|缓存|响应Cache-Control与重复请求|API no-store、assets独立|
|证书缺中间链|TLS|s_client chain|leaf后接intermediate fullchain|
|证书主机名错|TLS|verify_hostname/curl|签发正确SAN并SNI测试|
|read timeout过短|上游|error log时间线|按端点预算，理解非总时长|
|reload坏配置|发布|nginx -t失败|test通过才reload并回滚|

## 18. 概念卡

### 18.1 TLS终止与应用认证

TLS保护连接与服务器身份；Java认证识别用户。两层都必需。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.2 SNI与Host

SNI参与TLS证书/虚拟主机，Host参与HTTP server选择；测试应覆盖两者一致与不一致。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.3 server与location

server先按地址/Host选择，location再按URI选择。错误阶段不同，证据也不同。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.4 前缀与正则location

最长前缀和正则顺序共同作用；^~可阻止后续正则覆盖已选前缀。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.5 proxy_pass带URI与不带URI

带URI可能替换location前缀；不带通常保留请求URI。尾斜杠必须用测试固定。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.6 Host与X-Forwarded-Host

Host传递当前代理判断的主机；额外转发头按应用合同使用，不能全盘信任客户端。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.7 remote_addr与原始XFF

remote_addr由连接/可信realip模块建立；原始XFF只是客户端可控字符串。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.8 set_real_ip_from与防火墙

前者定义哪些代理头可信；防火墙限制谁能连接。二者相互补强。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.9 request ID与用户ID

request ID关联日志，不证明身份也不提供资源权限。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.10 connect timeout与read timeout

connect限制建连；read限制两次读取间隔，不是完整响应总时长。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.11 502与504

常分别指向上游连接/协议和超时，但最终以error log为证据，不靠状态码猜全部原因。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.12 缓冲与流式

缓冲适合普通响应与慢客户端隔离；SSE需专门关闭并验证取消与首事件延迟。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.13 叶证书与fullchain

叶证明站点身份，中间证书帮助客户端构建到信任根；服务器通常不发送根。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.14 证书文件名与密码学证据

叫fullchain.pem不证明链、SAN、有效期或key匹配；必须用openssl/真实客户端验证。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.15 renew与reload

renew取得新文件；reload让新worker使用它。两步之间先做配置和密码学校验。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.16 静态asset与index

hash asset可长缓存；index引用当前hash，应重新验证。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.17 SPA 404与API 404

SPA未知路由回index；API 404必须保持JSON/状态，不能回HTML 200。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.18 no-store与immutable

no-store适合敏感/动态响应；immutable适合URL内容寻址的静态文件。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.19 nginx -t与外部smoke

-t验证解析/引用，不证明DNS、监听、防火墙、完整握手和上游行为。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.20 代理授权与Java授权

Nginx可做入口限制，但Java必须对当前主体和工单重新授权。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.21 静态审计与真实Nginx

正则检查配置意图；真实语法与模块支持只能由目标nginx二进制证明。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

### 18.22 配置reload与制品晋级

手工reload改变运行状态；可追溯发布还需配置digest、审批、smoke与回滚记录。诊断时先指出请求停在哪一层，再选择日志、nginx、openssl或Java证据。

## 19. 实操路线

运行example和lab，确认静态审计接受显式API块、可信proxy CIDR、规范化转发头、三个timeout、fullchain清单、assets immutable、index no-cache与SPA fallback。注意输出明确UNVERIFIED。

运行public exercise，得到EXPECTED_RED与41。实现四项：拒绝任意XFF信任；要求API独立location；要求fullchain；禁止把长期缓存应用到敏感响应。private solution仅是静态参考。

具备目标Nginx后，运行nginx -v/-V、nginx -t/-T；生成受控测试证书或使用staging；openssl s_client带SNI验证链；curl矩阵验证Host、XFF伪造、Proto、request ID、API各状态、assets/index缓存与SPA。当前不能把这套计划标已完成。

## 20. 自测题

1. default_server与server_name分别怎样参与选择？
2. /api为何用独立^~ location？
3. proxy_pass尾斜杠可能怎样改变URI？
4. 为什么不能信任任意客户端X-Forwarded-For？
5. set_real_ip_from应从哪里获得真实CIDR？
6. proxy_read_timeout为何不是总响应时长？
7. fullchain文件的证书顺序怎样？
8. nginx -t通过不能证明哪些TLS事实？
9. 证书续期后为什么先test再reload？
10. index与hash asset为什么用不同缓存头？
11. API 404被SPA改成200会造成什么诊断假象？
12. Nginx为什么不能替Java做工单资源授权？
13. 当前fixture的TLS inventory证明了什么、没证明什么？

## 21. 120秒复述模板

Nginx先按listen/Host选择server，再按URI选择location。FactoryCare把/api放独立^~块，proxy_pass路径规则固定，向Java传Host、规范化来源、scheme和request ID，并设置连接/发送/读取超时；SPA fallback只在location /。只有可信代理CIDR的转发头可用于恢复来源，Java仍只信代理网络并自行认证授权。TLS使用匹配主机名的叶证书加中间链，续期后先验证、nginx -t再reload和外部握手。哈希assets长期immutable，index重新验证，API no-store。静态配置检查、nginx -t、openssl握手和端到端代理是四种不同证据；本章当前只有第一种。

## 22. 官方资料与当前验证边界

截至2026-07-24核对的一手资料：

- Nginx request processing：https://nginx.org/en/docs/http/request_processing.html
- ngx_http_core_module/location/try_files：https://nginx.org/en/docs/http/ngx_http_core_module.html
- ngx_http_proxy_module：https://nginx.org/en/docs/http/ngx_http_proxy_module.html
- ngx_http_realip_module：https://nginx.org/en/docs/http/ngx_http_realip_module.html
- Configuring HTTPS servers：https://nginx.org/en/docs/http/configuring_https_servers.html
- ngx_http_ssl_module：https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- Certbot renewal guide：https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates

本机ACTUAL：nginx命令不存在；Docker daemon不可连接。Python静态审计与合成TLS inventory通过。UNVERIFIED：Nginx版本/模块、nginx -t、证书SAN/有效期/key/链、TLS握手、reload、代理路径与头、超时、缓存和SPA端到端行为。
