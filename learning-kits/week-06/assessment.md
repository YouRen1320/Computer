# Week 06 无 AI 考核与阶段门 G1

本周有两个不同目的的考核：

- A：Week 06 并发/JVM 接管考核，证明你能修故障；
- B：阶段门 G1 Java 基础综合题，证明 Week 01—06 能连起来。

建议分两天完成。考核 A 复用本周实验 6—11 的设备补全代码；G1 工单服务复用 Week 01—05 已累积的 FactoryCare 工单模型。两个考核不是同一业务，不能互相替代，也不为任一考核另建重复工程。答案必须在两场提交后再看：[答案册](./answers.md)。

## 一、共同规则

- 每场编码限时 120 分钟；
- 允许 JDK 25 官方文档、项目源码、IDE 调试器和本机诊断命令；
- 禁止 AI、搜索答案、旧答案复制、开启 preview；
- 所有等待必须有上限；
- 保存开始/结束时间、测试输出和卡点；
- 口述另计 25 分钟，可录音；
- 环境失败时保留证据并纸面继续，不伪造测试通过。

## 二、考核 A：并发接管

### 已知系统

EquipmentEnrichmentService 调用：

- maintenance：必须成功；
- parts：允许超时降级；
- failureStats：允许失败降级。

你会拿到有故障的版本：

- 使用 newFixedThreadPool，无界队列；
- supplyAsync 未指定 Executor；
- 每个 Future 创建后立即 join；
- parts 超时用 null 降级；
- 捕获 InterruptedException 后继续；
- 按完成顺序把三个结果放入 List，字段会错配；
- Executor 从不关闭；
- 虚拟线程版本没有限制 PartsSource；
- 测试依赖长 sleep。

### 任务 A1：建立串行 oracle

先让串行版通过：

- 全成功；
- maintenance 失败整体失败；
- parts/stats 降级保留 source；
- 固定 Clock；
- 结果不用 null。

### 任务 A2：修平台线程池版

- 显式有界 ThreadPoolExecutor；
- 命名线程；
- 显式 Executor 传给 supplyAsync；
- 独立任务先启动再聚合；
- maintenance、parts、stats 结果不因完成顺序错配；
- Executor 生命周期完整；
- 饱和时明确失败。

### 任务 A3：超时和中断

- parts 超时返回明确降级对象；
- maintenance 超时仍整体失败；
- 取消时中断不被吞；
- Future 等待不永久挂起；
- 不能声称 orTimeout 已终止底层任务，需验证实际退出。

### 任务 A4：虚拟线程资源边界

- 使用每任务虚拟线程；
- 不建立固定虚拟线程池；
- PartsSource 许可数为 2；
- 运行至少 10 个设备任务，最大 PartsSource 活跃数不得超过 2；
- acquire 中断正确处理，permit 不泄漏；
- 不使用 StructuredTaskScope。

### 任务 A5：故障定位

从以下任选一项：

1. 修复共享 ArrayList 并发写；
2. 修复 lost update；
3. 修复未关闭 Executor 导致进程不退出。

提交证据链：现象、假设、工具、结果、根因、修复、回归测试。

### 任务 A6：算法

无 AI 实现 lowerBound：

- 输入升序 int 数组和 target；
- 返回第一个大于等于 target 的索引；
- 若所有值都小于 target，返回 length；
- 使用 [left,right)；
- 覆盖空、单个、重复、两端和不存在；
- O(log n)。

## 三、考核 A 评分

| 部分 | 分值 | 满分证据 |
| --- | ---: | --- |
| 概念解释 | 20 | 并发、原子、可见、中断、虚拟线程和 JVM 口述准确 |
| 最小实验 | 15 | 饱和、中断、超时、Semaphore 有可重复证据 |
| 项目增量（FactoryCare） | 25 | 串行、平台池、虚拟线程三版满足同一契约 |
| 测试与排错 | 20 | 无 sleep 猜测；错配、失败、取消、关闭有测试 |
| 无 AI 任务 | 15 | 限时修复 + lowerBound |
| 复盘与求职 | 5 | 证据链和诚实项目表达 |

FactoryCare 25 分：

- 串行 oracle：4；
- 有界平台池与组合：7；
- 超时/降级语义：5；
- 虚拟线程 + Semaphore：6；
- 生命周期与可观测结果：3。

测试与排错 20 分：

- 可控协调而非长 sleep：4；
- 完成顺序错配：4；
- 必须成功/可降级：4；
- 中断、取消、超时：5；
- Executor 与 permit 清理：3。

无 AI 15 分：

- 主要缺陷修复：8；
- lowerBound 正确与边界：4；
- 能解释区间不变量：3。

### 考核 A 门槛

总分至少 75，且：

- 项目增量（FactoryCare）至少 15/25；
- 测试与排错至少 12/20；
- 无 AI 至少 9/15；
- 无 common pool 关键任务；
- 无无界业务队列；
- 无吞中断；
- 无 null 降级；
- 无 Executor/permit 泄漏；
- 虚拟线程不突破稀缺资源上限；
- 无 preview。

## 四、考核 B：阶段门 G1

### 目标

120 分钟内实现或扩展一个纯 Java 内存版维修工单服务。它只考 Week 01—06，不引入 Spring、数据库、HTTP、Redis 或 Python。

### 必须功能

1. 创建设备；
2. 创建工单；
3. 工单号唯一；
4. 分配技师；
5. 合法最小状态流转；
6. 按状态和优先级组合查询；
7. 按技师统计未关闭工单；
8. 重复编号、非法状态、不存在对象抛明确异常；
9. JUnit 覆盖成功与失败；
10. 命令行可构建。

状态只使用最终词表的最小子集：

    CREATED → TRIAGED → ASSIGNED

不提前实现完整权限、SLA、审计和数据库并发。

### 领域最低要求

- EquipmentId、WorkOrderId、WorkOrderNo、TechnicianId 有清晰类型；
- `WorkOrderStatus` 和 `Priority` 使用 enum，不使用任意字符串；
- 实体保护关键不变量；
- 仓储不暴露内部可变集合；
- equals/hashCode 语义正确；
- 查询结果排序稳定；
- Optional 只用于可能缺失的返回边界；
- checked/unchecked 选择可解释；
- createdAt 可使用固定 Clock 测试。

### 必须测试

- 合法创建设备和工单；
- 重复工单号；
- 不存在设备；
- 分配不存在技师或工单；
- CREATED → TRIAGED；
- TRIAGED → ASSIGNED；
- 跳过状态的非法转换；
- 条件查询的空、单项和组合；
- 按技师统计只包含未关闭定义中的状态；
- 仓储快照不被外部修改；
- createdAt 固定；
- 至少一个异常 cause/语义测试（若存在基础设施适配器）。

### 15 分钟现场变更

主考完成后随机抽一项：

- 新增规则“受监管设备的优先级不得低于 `HIGH`”，并调整计算、查询与测试；
- 查询增加 createdAt 半开区间；
- 分配时若技师已有 3 张未关闭工单则拒绝，并补 2/3 边界测试（本周只保证单进程内存仓储的顺序语义）；
- 统计按优先级再分组；
- 工单摘要增加设备编码但不暴露实体。

必须同步改测试。

## 五、G1 口述

每题最多 90 秒：

1. class、record、interface、enum 的选择；
2. Java 是值传递是什么意思；
3. List、Set、Map 如何选择；
4. equals/hashCode 违约如何影响 HashMap 和 distinct；
5. 泛型不变性与通配符基础；
6. checked/unchecked 与 cause；
7. byte/char、UTF-8 和资源关闭；
8. Instant、LocalDateTime、ZonedDateTime、Clock；
9. Lambda 捕获与函数式接口；
10. Stream 与循环；
11. Optional 不适合的位置；
12. 线程、任务、并发、并行；
13. synchronized、volatile、AtomicInteger；
14. 线程池与虚拟线程；
15. 堆、栈、Metaspace、GC、JIT；
16. 线程转储能告诉你什么。

## 六、G1 通过标准

使用[阶段考核总规则](../../ASSESSMENTS.md)的 G1 标准：

- 测试通过，Maven 命令行构建；
- 120 分钟主要功能完成；
- 15 分钟变更完成并更新测试；
- 能指出 AI 版本至少三个边界或质量问题；
- 口述正确率至少 75%；
- 不要求背 JVM 或 Stream 源码。

推荐用 100 分记录：

| 项目 | 分值 |
| --- | ---: |
| 领域模型与不变量 | 20 |
| 仓储、集合和查询 | 20 |
| 状态与异常 | 15 |
| JUnit 成功/失败路径 | 20 |
| 15 分钟变更 | 10 |
| 口述 | 15 |

G1 总分至少 75，且功能/测试/现场变更不能低于各自 60%。

## 七、硬性失败

出现任一项需补考：

- 使用 Spring 或数据库绕过基础考核；
- 工单号唯一只靠测试数据，没有代码约束；
- 任意 setStatus 绕过合法流转；
- catch Exception 后假成功；
- 返回内部可变 List/Map；
- Optional.get 无保护；
- Stream 副作用或 parallelStream；
- 测试依赖真实时间；
- 无法从命令行构建；
- 无法解释自己提交的关键代码。

## 八、补考

考核 A 变体：

- PartsSource 必须成功，stats 可降级；
- Semaphore 从 2 改 1 并验证取消不泄漏；
- lowerBound 改为 upperBound。

G1 变体：

- 工单改为现场检查任务；
- 状态最小链改为 DRAFT → READY → ASSIGNED；
- 唯一键改为任务编号；
- 查询改为技师 + 优先级；
- 现场变更随机抽不同题。

## 九、复盘

    考核 A 得分：
    G1 得分：
    两次实际用时：
    我最严重的并发误解：
    我如何证明资源真正释放：
    我能独立完成的 Java 基础：
    我仍依赖 AI 的部分：
    进入 Spring 前必须补的两项：
    补考日期：
