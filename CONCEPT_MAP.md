# 全技术栈概念覆盖矩阵

## 使用方法

这份矩阵用于回答“有没有遗漏重要基础”。它不是第二份课程表，而是知识审计表：每项都标明目标等级和主要周次。

- L1：能解释问题、机制、适用场景和代价；
- L2：能借助官方资料/AI完成最小实验并验证；
- L3：能在FactoryCare使用、测试、修改和排错；
- L4：能比较方案，设计迁移、风险和回滚。

没有任何36周计划可以覆盖计算机全部知识。本矩阵覆盖目标岗位的主流知识面；专家级源码、超大规模和研究型内容明确保持L1。

## 1. 通用软件工程与计算机基础

| 概念 | 目标 | 主要周次/证据 |
| --- | --- | --- |
| 二进制、字符编码、数值精度、时间与时区 | L2 | Week 01、04、10 |
| 算法复杂度、空间/时间权衡 | L2 | Week 01—06并行算法线 |
| 数组、字符串、链表、栈、队列、哈希 | L2 | Week 01—06并行算法线 |
| 树、堆、二分、排序、DFS/BFS | L2 | Week 07—18并行算法线 |
| 递归、回溯、贪心、动态规划基础 | L1—L2 | Week 13—18、35 |
| 进程、线程、调度、内存、文件和信号 | L2 | Week 06、34 |
| TCP/IP、DNS、端口、HTTP、TLS、代理 | L2—L3 | Week 08、13、22、34 |
| Git工作区、暂存区、提交、分支、合并、rebase概念、回滚 | L3 | Week 00及全程 |
| 语义化版本、lockfile、依赖/BOM和供应链 | L3 | Week 00、07、27、34 |
| 编译、解释、字节码、JIT和运行时 | L2 | Week 01、06、27 |
| 调试器、日志、指标、trace和profile | L3 | Week 06、09、22、27、34 |
| 单元、集成、契约、组件、E2E和质量门 | L3 | Week 05、09、18、22、26、34 |
| 需求、验收、非目标、ADR、迁移与回滚 | L4 | 全程模板、Week 18、33—36 |
| 模块化、高内聚、低耦合、依赖方向 | L3—L4 | Week 02、07、18 |
| 常见设计模式：Strategy、Factory、Adapter、Observer、Repository | L2—L3 | 按问题分散在Week 02、07、17、18、29 |
| 安全威胁、最小权限、输入验证、密钥和审计 | L3 | Week 13—14、24、31、34 |
| 性能测量、基线、瓶颈和优化证据 | L2—L3 | Week 06、11、19、31、34 |

## 2. Web基础复健

这些内容不重新从零上课，但在Week 19前完成基线测试；薄弱项从项目和官方资料中定向补。

| 概念 | 目标 | 主要周次/证据 |
| --- | --- | --- |
| 语义化HTML、文档结构、表单、label和原生校验 | L3 | Week 19基线、20表单 |
| 可访问性：键盘、焦点、ARIA、对比度和错误提示 | L2—L3 | Week 19—22 |
| CSS cascade、specificity、inheritance、box model | L3 | Week 19基线 |
| Flexbox、Grid、定位、层叠上下文、响应式 | L3 | Week 19—20 |
| CSS变量、主题、动画和reduced motion | L2 | Week 19—20 |
| JS作用域、闭包、this、原型、class和模块 | L3 | Week 19基线 |
| 值/引用、不可变、浅/深复制和结构化克隆 | L3 | Week 19基线 |
| Event Loop、microtask/macrotask、Promise、async/await | L3 | Week 19、22 |
| DOM、事件捕获/冒泡、默认行为和事件委托 | L3 | Week 19基线 |
| Fetch、AbortController、流、SSE和WebSocket概念 | L3 | Week 19、22、29 |
| Cookie、Session、Storage、CORS、CSRF、XSS | L3 | Week 13、19—22 |
| 浏览器缓存、HTTP缓存、Service Worker概念 | L2 | Week 20、22、24 |
| 浏览器渲染、布局/绘制、资源加载和性能指标 | L2 | Week 19—21 |
| TypeScript联合、交叉、泛型、收窄、utility、unknown/never | L3 | Week 19—20 |
| TS编译配置、声明、模块解析和运行时验证边界 | L3 | Week 19—21 |

## 3. Java语言与JVM

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| 程序入口、控制台输入输出、基本/引用类型、控制流、方法 | L3 | Week 01 |
| class、record、interface、enum、sealed、值对象 | L3 | Week 02 |
| 继承/组合、封装、多态、SOLID适用边界 | L3 | Week 02、18 |
| 泛型、类型擦除、协变/逆变直觉 | L2—L3 | Week 03 |
| List/Set/Map、复杂度、equals/hashCode | L3 | Week 03 |
| checked/unchecked、异常链和资源管理 | L3 | Week 04 |
| IO/NIO、路径、编码、JSON和时间API | L2—L3 | Week 04 |
| Lambda、函数式接口、Stream、Collector、Optional | L3 | Week 05 |
| 线程、可见性、原子性、锁和并发集合 | L2—L3 | Week 06 |
| Executor、Future、CompletableFuture、取消和超时 | L3 | Week 06 |
| 虚拟线程与资源限流 | L2 | Week 06 |
| 类加载、堆/栈/Metaspace、GC、JIT和JFR | L2 | Week 06、34 |
| 反射、注解和代理高层机制 | L2 | Week 07、13 |
| Java模块系统、序列化安全和native image概念 | L1 | Week 06—07、34 |

## 4. Spring企业开发

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| Maven生命周期、坐标、scope、BOM、插件、Wrapper | L3 | Week 07 |
| IoC/DI、Bean、作用域、生命周期、配置 | L3 | Week 07 |
| AOP/代理、拦截器、过滤器的边界 | L3 | Week 07、13 |
| Boot自动配置、外部配置、Profile和Actuator | L2—L3 | Week 08、34 |
| MVC请求链、DTO、校验、序列化、统一错误 | L3 | Week 08 |
| REST、幂等、分页、版本、OpenAPI和SSE | L3 | Week 08—09、22、33 |
| 测试切片、MockMvc、Testcontainers和测试替身 | L3 | Week 09 |
| JDBC、连接池、MyBatis Core/Starter和映射 | L3 | Week 12 |
| Flyway、前滚迁移和兼容部署 | L3 | Week 12、33—34 |
| `@Transactional`、传播、隔离和代理失效 | L3 | Week 11—12 |
| Security过滤链、认证和授权 | L3 | Week 13 |
| Session、JWT、OAuth2、OIDC和CSRF/CORS | L2—L3 | Week 13 |
| RBAC、ABAC概念、数据范围、多租户和审计 | L3 | Week 14 |
| 领域模型、聚合、状态机、SLA和并发版本 | L3—L4 | Week 15 |
| Cache、幂等、限流、重试、熔断和一致性 | L3 | Week 16、29、34 |
| 定时/异步、领域事件、outbox、RabbitMQ | L2—L3 | Week 17 |
| Modulith、模块测试和事件发布日志 | L3—L4 | Week 18 |
| JPA、WebFlux、GraphQL、gRPC | L1 | Week 08、12、技术选型说明 |
| Spring Cloud、Nacos、Sentinel、Seata | L1 | Week 18/34“不采用”答辩 |

## 5. 数据库、缓存与存储

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| 关系、键、约束、NULL和规范化 | L3 | Week 10 |
| PostgreSQL类型、DDL/DML、JOIN、聚合、CTE、窗口 | L3 | Week 10 |
| B-tree、复合/部分/覆盖索引和选择性 | L3 | Week 11 |
| EXPLAIN、统计、VACUUM/MVCC概念 | L2—L3 | Week 11 |
| ACID、隔离、锁、死锁、乐观/悲观 | L3 | Week 11、15 |
| Redis数据结构、TTL、持久化和淘汰 | L2—L3 | Week 16 |
| 缓存穿透/击穿/雪崩、双写一致性 | L3 | Week 16 |
| 对象存储、元数据、预签名URL和生命周期 | L2—L3 | Week 24、30 |
| 全文、向量、HNSW/IVFFlat、hybrid search | L2—L3 | Week 30 |
| MySQL与PostgreSQL主要差异 | L1—L2 | Week 12集中对照实验 |
| 分区、复制、分库分表、独立搜索/向量库 | L1 | Week 11、30、34 |

## 6. Vue3、Nuxt与前端工程

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| Vue响应式、effect、ref/reactive、computed/watch | L3—L4 | Week 19 |
| SFC、script setup、Props/Emits/Slots/Provide | L3 | Week 19 |
| Composable、生命周期、副作用和取消 | L3—L4 | Week 19、22 |
| Router、守卫、URL状态、懒加载和404 | L3 | Week 20 |
| Pinia客户端状态与服务端状态缓存 | L3 | Week 20 |
| Vite、环境、代理、构建、chunk和source map | L3 | Week 20 |
| Element Plus复杂表单/表格和ECharts概念 | L3/L2 | Week 20、项目看板 |
| SSR、CSR、SSG、hydration、SEO、Nitro | L2—L3 | Week 21 |
| Nuxt路由、useFetch、server/client边界和部署 | L2—L3 | Week 21 |
| Vitest、Testing Library、Playwright | L3 | Week 22 |
| SSE重连、去重、取消、降级 | L3 | Week 22 |
| PWA、微前端、低代码和WebAssembly | L1 | 明确非目标/面试概念 |

## 7. uni-app与小程序

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| 小程序逻辑/渲染层、页面生命周期和路由 | L2—L3 | Week 23 |
| uni-app跨端编译、条件编译和平台适配 | L2—L3 | Week 23 |
| 登录code、服务端身份映射和会话 | L3 | Week 23 |
| 扫码、设备校验、幂等报修 | L3 | Week 23 |
| 真机、合法域名、权限和隐私 | L3 | Week 24 |
| 图片上传、进度、失败恢复和对象授权 | L3 | Week 24 |
| Storage、离线草稿、TTL和用户隔离 | L2—L3 | Week 24 |
| 订阅消息、推送、支付服务端流程 | L1 | Week 24 |
| 分包、包体、审核和发布 | L2 | Week 24 |
| 原生小程序/Taro/uni-app选型 | L1—L2 | Week 23 ADR |

## 8. Dart与Flutter

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| 空安全、类/mixin/extension、sealed、泛型 | L2—L3 | Week 25 |
| Future、Stream、event loop和isolate | L2—L3 | Week 25 |
| Widget/Element/RenderObject和生命周期 | L2—L3 | Week 25 |
| Context、Key、导航和深链 | L3 | Week 25 |
| UI/data层、Repository、Service和状态管理 | L3 | Week 25 |
| Riverpod/BLoC/Provider选型 | L2 | Week 25 |
| REST、OpenAPI、认证和secure storage | L3 | Week 26 |
| SQLite/Drift、offline-first、mutation queue | L3 | Week 26 |
| 幂等、同步冲突和恢复 | L3 | Week 26 |
| 相机、扫码、文件上传和权限 | L3 | Week 26 |
| 单元、Widget、Integration Test | L3 | Week 25—26 |
| flavor、签名、构建、推送和上架 | L2 | Week 26 |
| 原生插件、FFI、桌面和Flutter Web | L1 | 明确非目标 |

## 9. Python、ML与PyTorch

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| Python类型、数据模型、异常、context manager | L3 | Week 27 |
| iterator/generator、包、依赖和uv | L3 | Week 27 |
| async、task、取消、线程/进程池 | L3 | Week 27 |
| FastAPI、Pydantic、配置、日志和pytest | L3 | Week 27 |
| 监督/无监督、分类/回归/聚类 | L1—L2 | Week 28 |
| 训练/验证/测试、过拟合、泄漏和指标 | L2 | Week 28 |
| tensor、autograd、Module、loss、optimizer | L2 | Week 28 |
| Dataset/DataLoader、train/eval、checkpoint | L2 | Week 28 |
| 微调、量化、分布式训练、CUDA、MLOps | L1 | Week 28明确非目标 |

## 10. 大模型、RAG与Agent

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| provider/model、消息、token、context和采样 | L2—L3 | Week 29 |
| prompt模板、版本和上下文工程 | L3 | Week 29—32 |
| structured output和schema验证 | L3 | Week 29 |
| streaming、取消、重试、成本和限流 | L3 | Week 29、31 |
| tool calling、权限、参数和循环 | L3 | Week 29、32 |
| 解析、OCR概念、切块、embedding | L3 | Week 30 |
| vector/full-text/hybrid/rerank/citation | L3 | Week 30—31 |
| 文档版本、ACL、撤回和索引重建 | L3—L4 | Week 30 |
| 检索/生成/引用/无答案评估 | L3 | Week 31 |
| Prompt Injection、数据泄漏和AI安全 | L3 | Week 31 |
| trace、token/cost、model fallback和降级 | L3 | Week 31 |
| workflow、agent loop、state和memory | L3 | Week 32 |
| LangChain、LangGraph、checkpoint和HITL | L3 | Week 32 |
| MCP host/client/server、tool/resource/prompt | L2 | Week 32 |
| 多Agent、自托管模型、vLLM和GPU平台 | L1 | Week 32明确非目标 |

## 11. 运维、安全与生产化

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| Linux用户/权限、进程、信号、资源和日志 | L2—L3 | Week 09基础，Week 34生产化深化 |
| Docker image/layer/container/network/volume | L3 | Week 09基础，Week 34镜像与部署深化 |
| multi-stage、non-root、health/readiness | L3 | Week 34 |
| Nginx反代、TLS、上传、SSE和安全header | L3 | Week 34 |
| CI/CD、artifact、环境、审批和回滚 | L3 | Week 09、34 |
| 结构化日志、Micrometer、OpenTelemetry | L3 | Week 27、31、34 |
| PostgreSQL/对象存储备份恢复、RPO/RTO | L2—L3 | Week 34 |
| OWASP Web/API/LLM风险 | L2—L3 | Week 13—14、24、31、34 |
| 依赖、镜像、SBOM、secret和许可证 | L2 | Week 00、34、36 |
| 云服务、Serverless、Kubernetes、Service Mesh | L1 | Week 34选型答辩 |

## 12. 求职与职业能力

| 概念 | 目标 | 主要周次 |
| --- | --- | --- |
| 岗位采样、技能矩阵和数据边界 | L3 | Week 00及全程 |
| 事实库与多版简历 | L3 | Week 00、18、31、35 |
| 项目演示、架构讲解和故障故事 | L3—L4 | 各阶段门、Week 35—36 |
| 现场编码、SQL、调试和无AI接管 | L3 | 每周、最终G8 |
| AI使用说明、审查证据和诚实边界 | L4 | 全程 |
| 投递漏斗、反馈归因和策略调整 | L3 | 全程、Week 35—36 |
| Offer职责、团队、稳定、薪资和城市成本比较 | L2—L3 | Week 36 |

## 13. 如何处理遗漏

遇到新JD或面试题时，先判断：

1. 它是否属于目标岗位高频能力；
2. 是主线必须达到L3，还是只需L1；
3. 现有项目能否自然产生证据；
4. 加入后会挤掉什么；
5. 是否应修改本矩阵和某一周，而不是临时新增一条技术主线。

任何新增架构、数据/API契约、目录或跨模块内容，都先走方案比较和完成标准，再进入计划。
