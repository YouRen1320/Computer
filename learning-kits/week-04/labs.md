# Week 04 实验、FactoryCare 增量与故障注入

## 0. 实验规则

- 继续使用 Week 01—03 的纯 Java Maven 工程；
- 使用项目锁定的 JDK 25、JUnit 与 Jackson 3 版本；
- 不为了本讲义手工追逐单库最新 patch；
- 每个实验先写预期，再运行，再记录实际；
- 测试使用临时目录和固定 Clock；
- 不接 Spring、数据库、HTTP 或对象存储；
- 示例类名可按现有包调整，但职责不能混在一起。

建议为本周创建以下包：

    factorycare.boundary.catalog
    factorycare.boundary.snapshot
    factorycare.time
    factorycare.domain

这只是学习期组织，不是最终模块架构。

## 实验 1：异常传播、cause 与 suppressed

### 目标

观察原始异常、包装异常、丢失 cause 和资源关闭失败的诊断差异。

### 起始实现

创建一个会在读取时失败、关闭时也失败的 AutoCloseable：

    final class BrokenResource implements AutoCloseable {
        String read() throws IOException {
            throw new IOException("read failed");
        }

        @Override
        public void close() throws IOException {
            throw new IOException("close failed");
        }
    }

在测试中使用 try-with-resources，捕获最终 IOException，记录：

- getMessage；
- getCause；
- getSuppressed 的数量和内容；
- stack trace 中的第一处业务代码位置。

### 变体

1. 用 new CatalogReadException("读取失败") 包装但不传 cause；
2. 改为 new CatalogReadException("读取失败", cause)；
3. 比较两者定位成本；
4. 再写一个 catch Exception 后返回空列表的错误版本，用测试证明它把“空目录”和“读取失败”混淆。

### 验收

- 能指出主异常和 suppressed exception；
- 自定义异常保留 cause；
- 测试不只断言异常类型，还验证安全且稳定的上下文；
- 不断言完整操作系统错误文案。

## 实验 2：UTF-8、路径约束与原子写入

### 目标

证明文本编码、路径边界和“成功后替换”的行为。

### 任务 A：编码

使用 JUnit 的临时目录创建包含中文设备名的文件：

    设备编码,设备名称
    EQ-0001,一号空压机

显式以 StandardCharsets.UTF_8 写入和读取。再人为使用错误字符集读取，记录结果，但不要在断言中依赖某个平台一定产生哪种乱码。

### 任务 B：安全解析相对路径

实现一个最小函数：

    Path resolveInside(Path baseDir, String requestedName)

规则：

- requestedName 不能为空；
- 只接受相对路径；
- 先把可信 baseDir 转成规范化绝对路径；
- 在该绝对基准上 resolve 后 normalize；
- 结果必须仍在 normalized absolute baseDir 内；
- 拒绝 ../outside.json 和绝对路径。

本实验不声称已完全防御符号链接和 TOCTOU。把该限制写在复盘中。

### 任务 C：先写临时文件再替换

实现：

    void replaceUtf8(Path target, String content)

要求：

- 临时文件与目标文件位于同一目录；
- 先写入临时文件并关闭；
- 使用 `ATOMIC_MOVE` 请求原子移动，不把同时传入 `REPLACE_EXISTING` 当成保证：规范会在原子移动分支忽略其他选项；
- 若目标已存在，必须用当前支持平台/provider 的集成测试确认它会原子替换；若 provider 不支持原子移动或拒绝覆盖，按本周约定安全失败并保留旧目标；
- finally 或受控清理逻辑删除失败后的临时文件；
- 返回前目标内容必须完整。

### 故障注入

- target 的父目录不存在；
- target 是目录；
- 在 move 前抛出人为异常；
- 临时文件创建后写入失败；
- 原目标已有 old-content。

测试核心：任何失败场景下，旧目标不能变成半个新文件。

## 实验 3：Instant、ZoneId 与 Clock

### 目标

把“业务事实”和“展示时区”分开。

### 最小实验

固定时钟：

    Instant fixed = Instant.parse("2026-07-11T08:00:00Z");
    Clock clock = Clock.fixed(fixed, ZoneOffset.UTC);

创建工单并断言 createdAt 等于 fixed。然后：

1. 将 fixed 分别转换到 UTC、Asia/Shanghai 和 America/New_York；
2. 记录显示时间和 offset；
3. 证明三个 ZonedDateTime 的 toInstant 相同；
4. 使用 LocalDateTime.parse 解析一个无时区字符串；
5. 分别绑定上海和纽约 ZoneId，比较得到的 Instant；
6. 解释为什么不能让服务器默认时区代替业务选择。

### Duration 与 Period

写两个断言：

- Duration.between 两个 Instant；
- LocalDate.plus(Period.ofMonths(1))。

使用 1 月 31 日作为日期样例，观察日历运算；不要把一个月硬编码为 30 天。

## 实验 4：JSON 的四层验证

### 契约样例

    {
      "schemaVersion": 1,
      "equipment": [
        {
          "code": "EQ-0001",
          "name": "一号空压机",
          "modelCode": "AC-100"
        }
      ]
    }

### 数据类型

建议使用边界 DTO：

    record EquipmentCatalogDocument(
        int schemaVersion,
        List<EquipmentImportRow> equipment
    ) {}

    record EquipmentImportRow(
        String code,
        String name,
        String modelCode
    ) {}

不要直接将 JSON 映射到 Equipment 实体。

### 四组测试

1. 语法：缺右括号、非法逗号；
2. 结构：equipment 不是数组、schemaVersion 类型错误；
3. 字段：code 缺失、空白、过长、未知 model；
4. 领域：同文件重复 code、仓储已有 code。

明确未知字段策略，并用一个拼错的 equipmnt 字段证明策略生效。

### 错误报告

业务字段错误收集为：

    record ImportIssue(
        int rowIndex,
        String field,
        String code,
        String message
    ) {}

message 不能回显整条原始记录。rowIndex 明确从 0 还是 1 开始；建议对用户报告从 1 开始，对内部数组保持 0 开始并在边界转换。

## 实验 5：FactoryCare 设备目录导入

### 先写决策

在实现前回答：

1. JSON 语法损坏时整批如何处理？
2. 一条业务数据错误时，是整批拒绝、跳过错误行还是导入其余行？
3. 同文件重复和仓储重复是否同一错误 code？
4. 导入过程发生技术失败时，是否可能留下部分保存？

本周没有数据库事务。推荐采用“先解析并校验整批，全部业务有效后再写入内存仓储”的策略，避免部分保存。若现有仓储没有批量原子能力，先构建待保存列表并在单线程测试环境一次提交，同时明确这不是持久化事务。

### 推荐职责

- CatalogFileReader：只负责安全文件读取；
- CatalogJsonDecoder：只负责 JSON 到 DTO；
- EquipmentCatalogValidator：收集字段和批内重复问题；
- EquipmentMapper：DTO 到领域对象；
- EquipmentCatalogImporter：编排上述步骤；
- EquipmentRepository：查询和保存领域对象。

### 必测场景

| 场景 | 预期 |
| --- | --- |
| 合法两条记录 | 两个设备保存，报告成功 |
| 空 equipment | 明确允许空成功或拒绝，不能含糊 |
| JSON 损坏 | 技术/契约失败，无设备保存 |
| code 空白 | 业务错误带记录索引，无设备保存 |
| 同文件重复 | 两条相关记录可定位，无静默覆盖 |
| 仓储已存在 | 明确重复错误，无覆盖 |
| 未知字段 | 符合既定严格/兼容策略 |
| 文件不存在 | 保留 IOException cause |

## 实验 6：FactoryCare 工单快照导出

### 快照 DTO

只导出调用方需要的字段：

    record WorkOrderSnapshot(
        String workOrderNo,
        String equipmentCode,
        String statusCode,
        String priorityCode,
        Instant createdAt
    ) {}

定义稳定排序，例如按 workOrderNo 升序，避免每次导出因 Map 迭代顺序不同产生噪声。

### 验收

- 时间为 ISO-8601，语义是 Instant；
- enum 输出稳定 code，不输出 ordinal；
- 不泄漏内部异常、临时字段或未来敏感字段；
- 写入失败不破坏旧快照；
- 相同输入产生语义相同的 JSON；
- 目标路径被限制在可信导出目录。

## 实验 7：链表算法副线

### 题目 A：反转单链表

输入单链表头，返回反转后的头。要求先画三根引用：

- previous；
- current；
- next。

每次循环先保存 next，再修改 current.next。测试空链表、单节点、两节点、多个节点。

### 题目 B：判断是否有环

先给出 Set 方案，再给快慢引用方案。说明：

- 时间复杂度；
- 空间复杂度；
- 快慢引用为什么相遇意味着有环；
- 不修改链表结构。

本周无 AI 考核只需完成其中一道，另一道作为变体。

## 故障注入总表

| 编号 | 注入故障 | 应观察的证据 | 修复方向 |
| --- | --- | --- | --- |
| F04-01 | 包装时删除 cause | stack trace 在边界中断 | 传递 cause |
| F04-02 | 使用默认编码 | 不同环境可能解析不同 | 明确 UTF-8 |
| F04-03 | 用户路径为 ../secret | 逃出 baseDir | resolve、normalize、边界检查 |
| F04-04 | 直接覆盖目标，写一半失败 | 旧文件损坏 | 临时文件后替换 |
| F04-05 | 工单直接 Instant.now() | 固定断言偶发失败 | 注入 Clock |
| F04-06 | LocalDateTime 当审计时刻 | 无法唯一恢复时间线 | 使用 Instant |
| F04-07 | JSON 直接映射实体 | 无效状态进入领域 | DTO 与领域工厂分离 |
| F04-08 | enum 使用 ordinal | 重排常量破坏契约 | 稳定 code |

每次故障记录：现象、最初假设、最小复现、证据、根因、修复、回归测试。

## 完成命令与证据

至少执行并保存：

    java -version
    mvn -q test

若项目有格式化或静态检查，也执行现有命令。不要为了本周临时引入重量级插件。

最终证据应包括：

- 一次失败到修复的测试输出；
- 固定 Clock 的测试；
- 临时目录和旧文件保护测试；
- 损坏 JSON 与重复编码测试；
- 链表边界测试；
- [考核评分表](./assessment.md)。
