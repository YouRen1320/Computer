# 第34周：生产化、Linux、容器、CI/CD、观测与故障恢复

## 本周定位

本周把“开发机能跑”升级为“可重复部署、可观察、可恢复”。不追求云平台和Kubernetes复杂度，而是掌握中小企业应用真正需要的Linux、进程、网络、容器、反向代理、TLS、配置、CI、备份和故障处理。

## 前置条件

- Week 33形成的R6集成候选版本稳定；
- 自动化测试和演示数据可运行；
- 有一台本地Linux虚拟机、远程测试机或等价容器环境；
- 不使用真实敏感生产数据。

## 本周目标

- 掌握Linux文件、权限、进程、端口、磁盘、内存和日志基本排查；
- 构建安全、可缓存、可复现的Java/Python/Nuxt镜像；
- 用Docker Compose编排依赖与健康检查；
- 用Nginx完成反向代理、TLS和SSE配置；
- 建立CI质量门和受控部署/回滚；
- 建立日志、指标和trace；
- 完成数据库/对象存储备份恢复和8类故障演练。

## 必须理解的概念

### Linux与网络

- 用户/组、权限、文件、目录、链接和最小权限；
- process、thread、signal、exit code、service和graceful shutdown；
- CPU、内存、磁盘、文件描述符和常用观测命令；
- DNS、IP、port、TCP、HTTP、TLS和反向代理；
- connect/read/overall timeout；
- 日志轮转、时区、时间同步和磁盘满。

### 容器与部署

- image、layer、container、volume、network和registry；
- multi-stage build、non-root、read-only与最小镜像；
- build cache、架构平台和SBOM/漏洞扫描概念；
- Compose依赖、healthcheck和启动就绪区别；
- 配置与密钥外置，镜像不可变；
- 数据库迁移前滚、兼容窗口和回滚限制；
- blue/green、rolling、canary概念，项目采用简单可回滚发布；
- Kubernetes解决的问题和当前不采用的理由。

### 可观测与恢复

- logs、metrics、traces和profiles的不同；
- RED/USE指标、SLO/SLI概念；
- correlation ID和OpenTelemetry span；
- 告警必须可行动，避免只做漂亮面板；
- PostgreSQL逻辑/物理备份概念、RPO/RTO；
- 对象存储版本/生命周期和恢复；
- Redis不是备份的业务事实；
- runbook、incident timeline和postmortem。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务6的故障演练，不在总时长之外重复增加。

### 任务1：Linux排查实验（3小时）

- 查进程、端口、连接、CPU、内存、磁盘和日志；
- 制造端口占用、权限拒绝、磁盘接近满和进程退出；
- 使用`curl`/网络工具验证DNS、TLS、header和SSE；
- 记录命令的目的和证据，不背命令列表。

### 任务2：镜像与Compose（3小时）

- Java、Python和Nuxt使用多阶段构建；
- 非root运行、最小复制、明确版本；
- PostgreSQL、Redis、对象存储、身份提供方和OTel按profile组织；
- health/live与ready分别配置；
- volume和网络清楚，数据库不暴露公网；
- 一条命令启动核心演示，一条命令清理非持久数据。

### 任务3：Nginx/TLS和配置（2小时）

- 反向代理公共API、Nuxt和SSE；
- 配置上传大小、超时、buffering和安全header；
- 使用测试证书或受控真实证书演示TLS；
- 明确CORS、CSRF、cookie secure/samesite；
- 密钥通过环境/secret注入，不进镜像/仓库。

### 任务4：CI/CD（2—3小时）

- PR/提交运行Java、Node、Python、Flutter检查与测试；
- 构建镜像并进行依赖/镜像基础扫描；
- 数据库迁移先在临时库测试；
- 部署前有人工批准或受保护环境；
- 发布记录版本、commit和迁移；
- 失败能回滚旧镜像，数据迁移有前滚/恢复说明。

### 任务5：观测（2小时）

- 结构化日志含service、env、traceId和稳定错误码；
- OTel Collector接收Java/Python trace；
- 指标包含HTTP、DB、缓存、模型和队列关键项；
- 建立最小面板/查询；
- 敏感prompt/tool参数默认不导出。

### 任务6：备份与故障演练（3—4小时）

至少完成并记录：

1. 慢SQL；
2. Redis中断/清空；
3. Python/模型超时；
4. 对象上传失败；
5. 重复事件/HTTP请求；
6. PostgreSQL备份恢复；
7. 密钥/配置缺失；
8. Java/Python重启恢复。

每项写现象、检测、影响、证据、处置、恢复验证和预防。

## FactoryCare项目增量

- 生产候选Dockerfiles和Compose；
- Nginx/TLS/安全配置；
- CI/CD质量门；
- OTel跨服务trace和基础指标；
- PostgreSQL/对象存储备份恢复；
- 8类故障演练和runbook。

## AI协作边界

AI可以起草Dockerfile、CI和runbook，但必须人工核对镜像版本、权限、secret、端口、数据卷、迁移顺序和破坏性命令。不得让AI直接在真实服务器执行未审查删除、迁移或防火墙命令。

## 无AI训练（120分钟）

给出“Web返回502且AI流中断”的环境，只用日志、curl、进程/端口和trace定位Nginx→Java→Python中的故障；修复后验证SSE、健康检查和回滚。

## 求职动作

- 把部署、备份和故障证据加入R2/R3/R4简历；
- 模拟回答：Docker与虚拟机、health与ready、日志/指标/trace、Redis挂了怎么办、数据库迁移如何回滚、为什么不用K8s；
- 本周投递15个左右高匹配岗位并记录反馈。

## 交付物

- [ ] Linux排查记录；
- [ ] 安全多阶段镜像和Compose；
- [ ] Nginx/TLS与secret方案；
- [ ] CI/CD配置和一次发布/回滚；
- [ ] OTel trace和指标证据；
- [ ] 备份恢复记录；
- [ ] 8类故障演练和runbook；
- [ ] 无AI任务和周复盘。

## 验收标准

- 干净环境可按文档启动核心系统；
- 数据库和密钥不暴露/提交；
- 服务能优雅停止并正确报告readiness；
- 至少一次真实恢复备份，不只生成备份文件；
- trace可串联Java/Python；
- 故障记录有证据和恢复验证；
- G7生产化阶段门通过。

## 本周明确不做

- Kubernetes、Helm和Service Mesh；
- 自建复杂监控平台；
- 未授权真实生产部署；
- 只做面板不做故障演练；
- 假设镜像回滚能撤销数据迁移；
- 把所有secret放`.env`并提交。

## 官方资料

- [Docker documentation](https://docs.docker.com/)
- [Spring Boot production-ready features](https://docs.spring.io/spring-boot/reference/actuator/)
- [OpenTelemetry documentation](https://opentelemetry.io/docs/)
- [PostgreSQL backup and restore](https://www.postgresql.org/docs/current/backup.html)
- [Nginx documentation](https://nginx.org/en/docs/)
- [GitHub Actions documentation](https://docs.github.com/actions)
