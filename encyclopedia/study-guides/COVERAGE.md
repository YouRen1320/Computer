# 学习讲义覆盖索引

这份索引负责回答三个问题：每个学习周对应哪篇讲义、讲义放在哪里、它从哪个权威周次入口取材。正文仍以通俗连续阅读为目标；课程 outcome、考核和进度状态继续由 `weeks/`、`curriculum/` 与 `PROGRESS.md` 管理。

Week 03—48 的周次适配页一共引用了 **243 个不重复的权威章节**。下面的 66 篇讲义按主题重新组合这些内容；同一权威章节可能在后续周作为复习或支撑再次出现，因此各周“引用章节数”不能直接相加当作总数。

状态含义：

- `已生成`：讲义正文已经存在，可以连续阅读；
- `写作中`：正在把权威章节整理成通俗讲义；
- `待生成`：主题和路径已经确定，正文尚未写入。

## 阶段 1：Java 语言与运行时

| 周次 | 主题讲义 | 权威入口 | 引用章节数 | 状态 |
| --- | --- | --- | ---: | --- |
| 03 | [Java：类、对象、构造器与封装](./java/03-Java-类、对象、构造器与封装.md) | [Week 03](../weeks/week-03.md) | 6 | 已生成 |
| 04 | [Java：继承、接口、多态与类型建模](./java/04-Java-继承、接口、多态与类型建模.md) | [Week 04](../weeks/week-04.md) | 6 | 已生成 |
| 05 | [Java：集合、泛型、相等性与排序](./java/05-Java-集合、泛型、相等性与排序.md) | [Week 05](../weeks/week-05.md) | 9 | 已生成 |
| 06 | [Java：异常、文件、时间与 JSON](./java/06-Java-异常、文件、时间与JSON.md) | [Week 06](../weeks/week-06.md) | 8 | 已生成 |
| 07 | [Java：Lambda、Stream 与 Optional](./java/07-Java-Lambda、Stream与Optional.md) | [Week 07](../weeks/week-07.md) | 5 | 已生成 |
| 08A | [Java：线程、并发与虚拟线程](./java/08A-Java-线程、并发与虚拟线程.md) | [Week 08](../weeks/week-08.md) | 12（与 08B 合计） | 已生成 |
| 08B | [Java：JVM、反射、网络与诊断](./java/08B-Java-JVM、反射、网络与诊断.md) | [Week 08](../weeks/week-08.md) | 同上 | 已生成 |

## 阶段 2：Spring 与数据

| 周次 | 主题讲义 | 权威入口 | 引用章节数 | 状态 |
| --- | --- | --- | ---: | --- |
| 09A | [Java：Maven 与可重复构建](./java/09A-Java-Maven与可重复构建.md) | [Week 09](../weeks/week-09.md) | 11（与 09B 合计） | 已生成 |
| 09B | [Spring：IoC、Bean、配置与 AOP](./spring/09B-Spring-IoC、Bean、配置与AOP.md) | [Week 09](../weeks/week-09.md) | 同上 | 已生成 |
| 10 | [Spring Boot：REST、DTO、校验与错误处理](./spring/10-Spring-Boot-REST、DTO、校验与错误处理.md) | [Week 10](../weeks/week-10.md) | 12 | 已生成 |
| 11 | [Spring：测试、Testcontainers 与 OpenAPI](./spring/11-Spring-测试、Testcontainers与OpenAPI.md) | [Week 11](../weeks/week-11.md) | 10 | 已生成 |
| 12A | [SQL：关系模型、查询与数据修改](./sql/12A-SQL-关系模型、查询与数据修改.md) | [Week 12](../weeks/week-12.md) | 11（与 12B 合计） | 已生成 |
| 12B | [SQL：聚合、JOIN、子查询与窗口函数](./sql/12B-SQL-聚合、JOIN、子查询与窗口函数.md) | [Week 12](../weeks/week-12.md) | 同上 | 已生成 |
| 13 | [PostgreSQL：建模、约束、类型与迁移](./postgresql/13-PostgreSQL-建模、约束、类型与迁移.md) | [Week 13](../weeks/week-13.md) | 8 | 已生成 |
| 14 | [PostgreSQL：索引、执行计划、事务与锁](./postgresql/14-PostgreSQL-索引、执行计划、事务与锁.md) | [Week 14](../weeks/week-14.md) | 7 | 已生成 |
| 15 | [Spring：MyBatis、Flyway 与事务边界](./spring/15-Spring-MyBatis、Flyway与事务边界.md) | [Week 15](../weeks/week-15.md) | 11 | 已生成 |

## 阶段 3：安全与企业后端

| 周次 | 主题讲义 | 权威入口 | 引用章节数 | 状态 |
| --- | --- | --- | ---: | --- |
| 16A | [Web 安全：威胁模型、Cookie、CORS 与 CSRF](./security/16A-Web安全-威胁模型、Cookie、CORS与CSRF.md) | [Week 16](../weeks/week-16.md) | 15（与 16B、16C 合计） | 已生成 |
| 16B | [Spring Security：登录、Session 与请求保护](./security/16B-Spring-Security-登录、Session与请求保护.md) | [Week 16](../weeks/week-16.md) | 同上 | 已生成 |
| 16C | [OAuth、JWT 与 OIDC](./security/16C-OAuth-JWT与OIDC.md) | [Week 16](../weeks/week-16.md) | 同上 | 已生成 |
| 17 | [权限、多租户、数据隔离与审计](./security/17-权限、多租户、数据隔离与审计.md) | [Week 17](../weeks/week-17.md) | 7 | 已生成 |
| 18 | [领域模型、工单状态机、SLA 与乐观锁](./architecture/18-领域模型、工单状态机、SLA与乐观锁.md) | [Week 18](../weeks/week-18.md) | 8 | 已生成 |
| 19 | [Redis、缓存、幂等与限流](./architecture/19-Redis、缓存、幂等与限流.md) | [Week 19](../weeks/week-19.md) | 5 | 已生成 |
| 20 | [领域事件、Outbox 与 RabbitMQ](./architecture/20-领域事件、Outbox与RabbitMQ.md) | [Week 20](../weeks/week-20.md) | 4 | 已生成 |
| 21 | [模块化单体、Spring Modulith 与可观测性](./architecture/21-模块化单体、Spring-Modulith与可观测性.md) | [Week 21](../weeks/week-21.md) | 5 | 已生成 |

## 阶段 4：Web、TypeScript、Vue 与 Nuxt

| 周次 | 主题讲义 | 权威入口 | 引用章节数 | 状态 |
| --- | --- | --- | ---: | --- |
| 22A | [HTML：语义、表单、媒体与无障碍](./web/22A-HTML-语义、表单、媒体与无障碍.md) | [Week 22](../weeks/week-22.md) | 15（与 22B 合计） | 已生成 |
| 22B | [CSS：层叠、布局、响应式与动效](./web/22B-CSS-层叠、布局、响应式与动效.md) | [Week 22](../weeks/week-22.md) | 同上 | 已生成 |
| 23A | [JavaScript：值、控制流、函数与作用域](./javascript/23A-JavaScript-值、控制流、函数与作用域.md) | [Week 23](../weeks/week-23.md) | 16（与 23B 合计） | 已生成 |
| 23B | [JavaScript：集合、对象、原型与模块](./javascript/23B-JavaScript-集合、对象、原型与模块.md) | [Week 23](../weeks/week-23.md) | 同上 | 已生成 |
| 24A | [JavaScript：DOM、事件与表单](./javascript/24A-JavaScript-DOM、事件与表单.md) | [Week 24](../weeks/week-24.md) | 14（与 24B 合计） | 已生成 |
| 24B | [JavaScript：事件循环、Fetch、取消与浏览器安全](./javascript/24B-JavaScript-事件循环、Fetch、取消与浏览器安全.md) | [Week 24](../weeks/week-24.md) | 同上 | 已生成 |
| 25 | [TypeScript：类型系统、泛型、收窄与运行时边界](./typescript/25-TypeScript-类型系统、泛型、收窄与运行时边界.md) | [Week 25](../weeks/week-25.md) | 9 | 已生成 |
| 26A | [Vue：模板、表单与响应式](./vue/26A-Vue-模板、表单与响应式.md) | [Week 26](../weeks/week-26.md) | 15（与 26B 合计） | 已生成 |
| 26B | [Vue：组件、生命周期与 Composable](./vue/26B-Vue-组件、生命周期与Composable.md) | [Week 26](../weeks/week-26.md) | 同上 | 已生成 |
| 27 | [Vue：Router、Pinia、服务端状态与权限](./vue/27-Vue-Router、Pinia、服务端状态与权限.md) | [Week 27](../weeks/week-27.md) | 10 | 已生成 |
| 28 | [Nuxt：渲染、水合、数据获取与部署](./nuxt/28-Nuxt-渲染、水合、数据获取与部署.md) | [Week 28](../weeks/week-28.md) | 12 | 已生成 |
| 29 | [Web：测试、错误恢复、SSE 与性能](./web/29-Web-测试、错误恢复、SSE与性能.md) | [Week 29](../weeks/week-29.md) | 15 | 已生成 |

## 阶段 5：uni-app、Dart 与 Flutter

| 周次 | 主题讲义 | 权威入口 | 引用章节数 | 状态 |
| --- | --- | --- | ---: | --- |
| 30 | [uni-app：运行模型、页面、组件与网络](./uniapp/30-uni-app-运行模型、页面、组件与网络.md) | [Week 30](../weeks/week-30.md) | 10 | 已生成 |
| 31 | [uni-app：设备能力、离线、测试与发布](./uniapp/31-uni-app-设备能力、离线、测试与发布.md) | [Week 31](../weeks/week-31.md) | 11 | 已生成 |
| 32 | [Dart：类型、空安全、控制流与集合](./dart/32-Dart-类型、空安全、控制流与集合.md) | [Week 32](../weeks/week-32.md) | 6 | 已生成 |
| 33 | [Dart：对象、泛型、异步、Stream 与测试](./dart/33-Dart-对象、泛型、异步、Stream与测试.md) | [Week 33](../weeks/week-33.md) | 6 | 已生成 |
| 34 | [Flutter：Widget、布局、导航与状态](./flutter/34-Flutter-Widget、布局、导航与状态.md) | [Week 34](../weeks/week-34.md) | 10 | 已生成 |
| 35 | [Flutter：架构、网络、离线、设备与发布](./flutter/35-Flutter-架构、网络、离线、设备与发布.md) | [Week 35](../weeks/week-35.md) | 10 | 已生成 |

## 阶段 6：Python、机器学习与 AI

| 周次 | 主题讲义 | 权威入口 | 引用章节数 | 状态 |
| --- | --- | --- | ---: | --- |
| 36 | [Python：语法、类型、控制流、函数与模块](./python/36-Python-语法、类型、控制流、函数与模块.md) | [Week 36](../weeks/week-36.md) | 9 | 已生成 |
| 37A | [Python：类、类型标注、迭代器与资源管理](./python/37A-Python-类、类型标注、迭代器与资源管理.md) | [Week 37](../weeks/week-37.md) | 11（与 37B 合计） | 已生成 |
| 37B | [Python：NumPy、Pandas、测试与调试](./python/37B-Python-NumPy、Pandas、测试与调试.md) | [Week 37](../weeks/week-37.md) | 同上 | 已生成 |
| 38 | [Python：asyncio、FastAPI、Pydantic 与服务测试](./python/38-Python-asyncio、FastAPI、Pydantic与服务测试.md) | [Week 38](../weeks/week-38.md) | 8 | 已生成 |
| 39A | [数学：机器学习需要的数学基础](./machine-learning/39A-数学-机器学习需要的数学基础.md) | [Week 39](../weeks/week-39.md) | 22（与 39B—39D 合计） | 已生成 |
| 39B | [机器学习：数据、监督学习、无监督学习与评估](./machine-learning/39B-机器学习-数据、监督学习、无监督学习与评估.md) | [Week 39](../weeks/week-39.md) | 同上 | 已生成 |
| 39C | [深度学习：神经网络、反向传播与 Transformer](./machine-learning/39C-深度学习-神经网络、反向传播与Transformer.md) | [Week 39](../weeks/week-39.md) | 同上 | 已生成 |
| 39D | [PyTorch：张量、模型、训练与推理](./pytorch/39D-PyTorch-张量、模型、训练与推理.md) | [Week 39](../weeks/week-39.md) | 同上 | 已生成 |
| 40A | [大模型：Transformer、模型 API、提示与结构化输出](./ai/40A-大模型-Transformer、模型API、提示与结构化输出.md) | [Week 40](../weeks/week-40.md) | 21（与 40B 合计） | 已生成 |
| 40B | [大模型：流式响应、重试、降级与工具调用](./ai/40B-大模型-流式响应、重试、降级与工具调用.md) | [Week 40](../weeks/week-40.md) | 同上 | 已生成 |
| 41A | [信息检索：文档处理、分块、词项与 Embedding](./rag/41A-信息检索-文档处理、分块、词项与Embedding.md) | [Week 41](../weeks/week-41.md) | 12（与 41B 合计） | 已生成 |
| 41B | [RAG：pgvector、混合检索、引用与评估](./rag/41B-RAG-pgvector、混合检索、引用与评估.md) | [Week 41](../weeks/week-41.md) | 同上 | 已生成 |
| 42A | [AI：评估、成本、监控与降级](./ai/42A-AI评估、成本、监控与降级.md) | [Week 42](../weeks/week-42.md) | 19（与 42B 合计） | 已生成 |
| 42B | [AI 安全：提示注入、ACL、PII 与可观测性](./ai/42B-AI安全-提示注入、ACL、PII与可观测性.md) | [Week 42](../weeks/week-42.md) | 同上 | 已生成 |
| 43A | [LangChain 与 LangGraph](./agents/43A-LangChain与LangGraph.md) | [Week 43](../weeks/week-43.md) | 7（与 43B 合计） | 已生成 |
| 43B | [MCP、Agent 边界与人工审批](./agents/43B-MCP、Agent边界与人工审批.md) | [Week 43](../weeks/week-43.md) | 同上 | 已生成 |

## 阶段 7：联调、生产交付与职业表达

| 周次 | 主题讲义 | 权威入口 | 引用章节数 | 状态 |
| --- | --- | --- | ---: | --- |
| 44 | [全链路契约、系统边界与联调](./architecture/44-全链路契约、系统边界与联调.md) | [Week 44](../weeks/week-44.md) | 10 | 已生成 |
| 45A | [Linux、Docker 与 Compose](./production/45A-Linux、Docker与Compose.md) | [Week 45](../weeks/week-45.md) | 14（与 45B 合计） | 已生成 |
| 45B | [Nginx、TLS 与 CI/CD](./production/45B-Nginx、TLS与CI-CD.md) | [Week 45](../weeks/week-45.md) | 同上 | 已生成 |
| 46A | [日志、指标、链路、SLO 与性能](./production/46A-日志、指标、链路、SLO与性能.md) | [Week 46](../weeks/week-46.md) | 10（与 46B 合计） | 已生成 |
| 46B | [配置安全、备份恢复与故障响应](./production/46B-配置安全、备份恢复与故障响应.md) | [Week 46](../weeks/week-46.md) | 同上 | 已生成 |
| 47 | [作品集、系统设计与项目表达](./career/47-作品集、系统设计与项目表达.md) | [Week 47](../weeks/week-47.md) | 8 | 已生成 |
| 48A | [制品、部署、迁移与回滚](./production/48A-制品、部署、迁移与回滚.md) | [Week 48](../weeks/week-48.md) | 9（与 48B 合计） | 已生成 |
| 48B | [FactoryCare 验收、发布与下一阶段](./career/48B-FactoryCare验收、发布与下一阶段.md) | [Week 48](../weeks/week-48.md) | 同上 | 已生成 |

## 覆盖边界

- 这里的“覆盖”表示对应讲义已把该周权威章节整理进连续概念地图，不表示学习者已经掌握，也不改变 `PROGRESS.md`。
- 同一概念在多个周次出现时，后面的讲义只保留当前项目所需角度，不机械复制前文。
- 版本会变化的框架、库和平台行为在真正学习或维护讲义时仍要查看官方文档；本索引不锁定未来版本。
- 项目要求、测试范围、阶段门题目和答案不会写进这些概念讲义。
