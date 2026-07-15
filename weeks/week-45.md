# 第 45 周：Linux、Docker、Nginx/TLS 与 CI/CD

## 定位

本周先解决“怎样从源码得到可重复运行的系统”，Week 46 再集中处理观测、备份、安全和故障恢复。目标是能在 Linux 环境诊断进程/端口/文件，构建安全镜像，用 Compose 编排，用 Nginx/TLS 暴露服务，并通过 CI 产生可追溯制品和受控部署。

时间预算：15—18 小时。不引入 Kubernetes；本地/测试环境完成全部实验，不操作未知生产系统。

## 前置

- Week 44 全链路契约候选稳定；
- Java、Web、Python、Flutter/uni-app 的测试和构建命令明确；
- 有 Linux VM/远程测试机或等价容器环境；
- 密钥、配置和演示数据已与源码分离；
- 重大部署方案已完成选择和回滚标准。

## 目标

- 使用 Linux 文件、权限、用户、进程、信号、端口、资源和日志命令定位问题；
- 理解 DNS/IP/TCP/HTTP/TLS/反向代理的请求路径；
- 为 Java、Python、Nuxt 构建可缓存、非 root、可复现的多阶段镜像；
- 使用 Compose 定义网络、volume、health/readiness、配置和依赖；
- 使用 Nginx 配置 TLS、反代、上传、SSE 和安全 header；
- 设计 CI 的 checkout/cache/build/test/scan/artifact 阶段；
- 理解迁移、部署顺序、兼容窗口、审批和回滚限制；
- 完成一次测试环境部署与回滚演练。

## 完整概念清单

### Linux 基础

- filesystem hierarchy、绝对/相对路径、link、mount、权限位；
- user/group、owner、`chmod/chown`、最小权限、sudo 边界；
- process/thread/PID/parent、foreground/background；
- exit code、environment、working directory、stdin/out/err；
- signal、SIGTERM、graceful shutdown、SIGKILL 边界；
- `ps/top`、`lsof/ss`、`df/du`、`free/vm_stat` 对应能力，命令按平台核对；
- journal/service/log file、tail/search/rotation；
- CPU、内存、磁盘、inode、file descriptor 和端口冲突；
- shell 管道和重定向不泄漏敏感信息。

### 网络与 TLS

- DNS 解析、IP、port、socket、TCP connection；
- HTTP request/response、keep-alive、proxy header；
- connect/read/write/overall timeout；
- reverse proxy 与 application server；
- TLS certificate/private key/chain/hostname/expiration；
- TLS termination 后的内部信任边界；
- CORS 不替代防火墙/认证；
- curl/dig/nslookup/openssl 等工具按目标环境使用。

### 容器

- image/layer/container/registry/network/volume；
- Dockerfile build context、`.dockerignore`、cache；
- multi-stage build、固定 base digest/版本策略；
- 非 root、只读 filesystem、capability 和最小镜像；
- entrypoint/cmd、PID 1、signal 转发；
- environment/config/secret 不烘焙进镜像；
- healthcheck 与 readiness/startup 区别；
- volume 生命周期、数据库数据不能留在可丢 container layer；
- architecture（arm64/amd64）和多平台制品；
- SBOM、镜像扫描和签名概念。

### Compose 与 Nginx

- service/network/volume/config/secret；
- `depends_on` 不等于应用就绪，客户端仍需合理重试；
- 数据库迁移作为受控步骤，不由每个副本竞争执行；
- Nginx upstream、proxy header、body size、timeout；
- SSE 禁止不当 buffering/cache 并设置合理长连接；
- TLS 重定向、HSTS 谨慎、secure header；
- 静态资源缓存与带 hash 制品；
- 日志保留、客户端真实 IP 和 trace ID。

### CI/CD

- CI 与 CD、pipeline/job/step/runner/artifact/environment；
- lockfile、可重复构建、依赖缓存与缓存键；
- format/lint/type/test/integration/contract/build/scan 顺序；
- secret scope、OIDC 临时凭证概念、不在日志输出；
- artifact/image tag 用 commit SHA/版本，不使用不可追溯 `latest`；
- migration 的 expand/contract 和前后兼容窗口；
- rolling/blue-green/canary 概念，本项目选简单可回滚方式；
- 应用镜像可回滚，数据库迁移通常不能简单镜像回退；
- deployment approval、smoke test、rollback trigger 和审计。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| Linux/网络诊断 | 3h | 进程、端口、权限、磁盘和请求路径记录 |
| 镜像 | 3—4h | Java/Python/Nuxt 多阶段非 root 镜像 |
| Compose | 2—3h | 服务、数据库、Redis、对象存储、健康检查 |
| Nginx/TLS | 2—3h | REST/SSE/静态资源反代和证书实验 |
| CI/CD | 3h | 全栈质量门、artifact/image 和测试部署 |
| 回滚/复盘 | 2h | 部署、烟雾、旧版本回滚和证据 |

## FactoryCare 增量

- 单命令启动开发/演示核心依赖，应用就绪有真实健康检查；
- Java、Python、Nuxt 镜像不以 root 运行，不包含源码密钥；
- Nginx 支持 REST、上传、Nuxt 和 SSE；
- CI 运行 Java/Node/Python 核心检查和契约漂移；Flutter/uni-app 按可用 runner 分层；
- 产生带 commit SHA 的制品与镜像；
- 在测试环境完成前滚部署、烟雾测试和应用版本回滚；
- 记录数据库迁移为何未直接回滚以及恢复策略。

## 故障实验

1. 端口占用与错误监听地址；
2. 配置/密钥缺失导致 fail-fast；
3. 文件权限或只读 filesystem；
4. 健康检查通过但业务依赖未就绪；
5. Nginx buffering 导致 SSE 不流式；
6. arm64 构建在 amd64 环境无法运行或性能异常；
7. CI 缓存污染/lockfile 漂移；
8. 新应用读取旧/新 schema 的兼容性。

## 无 AI 任务（150 分钟）

从干净 checkout 构建一个服务镜像、启动依赖、经 Nginx 调用健康与一个业务 API、停止并重新启动验证数据 volume；修改应用版本，生成新制品，部署后烟雾失败再回滚。提交命令、退出码、日志、镜像标签和未回滚的数据迁移说明。

## 验收

- 能从 Linux 证据定位进程、端口、权限、磁盘或配置问题；
- 镜像多阶段、非 root、无密钥且可重复构建；
- Compose 的启动顺序不被误当就绪保证；
- Nginx REST/SSE/TLS 测试通过；
- CI 产生可追溯制品并阻止测试失败部署；
- 能解释应用回滚与数据迁移回滚为何不同。

## 非目标

- 不学习 Kubernetes、Service Mesh 或云厂商全套平台；
- 不操作真实生产数据和证书；
- 不把 `docker compose up` 成功等同生产可用；
- 不在本周完成全部观测/备份/故障演练，留到 Week 46。
