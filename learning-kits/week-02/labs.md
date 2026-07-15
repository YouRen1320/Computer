# Week 02 实验手册

本周所有业务代码仍在纯 Java 模块中。每个类型创建前先写“身份、可变性、不变量、公开行为、相等语义”五列，不从生成 class 开始。

## Lab 1：封装不是 setter（75 分钟）

### 反例

先创建一个 `MutableWorkOrderDraft`，有 public `setId`、`setStatus`、`setDescription`。用测试构造：空 id、空描述、任意状态字符串、创建后把 id 改掉。

### 重构任务

- 构造时要求 id 和描述有效；
- 移除通用 `setStatus`；
- 用有意图的方法修改允许变化的内容；
- 新对象初始状态固定为 `CREATED`；
- 测试调用方无法通过公开 API 构造明显非法状态。

本实验只比较边界，不实现完整状态转换。

### 验收

- 能指出反例中每个非法状态在哪里进入；
- 重构后规则集中；
- 没有通过“在 getter 里兜底”隐藏非法字段。

## Lab 2：Value Object 与 record（90 分钟）

分别设计：

- `EquipmentId`：非 null、非空白；是否 trim 需写理由；
- `WorkOrderId`：非 null、非空白，不绑定数据库自增；
- `FaultDescription`：trim 后 10—500 个 Java `char` 单位；本周明确这不是完整 Unicode 字素计数；
- 一个“过度包装”反例，并说明为什么删除。

测试：合法、null、空、空白、长度边界、规范化后相等、`toString` 是否会泄漏不应暴露的数据。

### 验收

- compact constructor 创建时验证；
- 两个规范值相同的 VO 相等且 hashCode 一致；
- 规则失败信息包含业务字段；
- 没有 public setter。

## Lab 3：enum、稳定 code 与唯一状态词表（75 分钟）

### `Priority`

声明 `LOW`、`MEDIUM`、`HIGH`、`CRITICAL`，每项有稳定 code。将 Week 01 计算器重构为返回 `Priority`，删除字符串 rank/拼写风险。

### `WorkOrderStatus`

只声明：

```text
CREATED, TRIAGED, ASSIGNED, ACCEPTED, IN_PROGRESS,
PENDING_PARTS, PENDING_APPROVAL, RESOLVED, VERIFIED,
CLOSED, REOPENED, CANCELLED
```

每项 code 与外部契约一致，不使用 ordinal。新工单只从 `CREATED` 开始。本周禁止编写任意状态转换接口，也不要新增别名。

### 故障实验

写一个依赖 `ordinal()` 的断言，然后调整 enum 声明顺序，观察语义如何悄悄变化。删除这种实现，改为稳定 code 测试。

## Lab 4：浅层不可变故障（60 分钟）

创建一个包含 `int[]` 的 record，例如严重度阈值配置：

1. 传入数组后从外部修改；
2. 通过访问器取出数组再修改；
3. 证明 record 默认实现并未阻止；
4. 构造时复制并在访问时返回副本；
5. 重新运行测试。

附加思考：数组进入 record 的默认 `equals` 按什么比较？这也是为什么“record 自动值语义”不代表组件选择永远正确。

## Lab 5：interface 与组合（60 分钟）

让优先级计算器实现 `PriorityPolicy`，调用方只依赖该契约。回答：

- 是否真的有替代实现或测试边界；
- 若只有一个简单类，interface 带来什么成本；
- `WorkOrder has-a PriorityPolicy` 是否合理，还是创建服务持有它更合理；
- 为什么 `WorkOrder extends BaseEntity` 没有足够理由。

不要创建抽象工厂或多层泛型。

## Lab 6：FactoryCare 第一版纯 Java 模型（3—4 小时）

### 类型职责表

| 类型 | 分类 | 最低不变量/行为 |
| --- | --- | --- |
| `EquipmentId` | Value Object | 非空、稳定值 |
| `WorkOrderId` | Value Object | 非空、与数据库键解耦 |
| `FaultDescription` | Value Object | trim后10—500 |
| `Priority` | enum | 稳定code、可升级且封顶 |
| `WorkOrderStatus` | enum | 只含唯一状态词表 |
| `Equipment` | Entity class | id和基本信息创建即有效 |
| `WorkOrder` | Entity class | id、设备、描述、优先级，初始CREATED |

### 行为要求

- `WorkOrder.create(...)` 隐藏初始状态；
- 可提供 `reviseFaultDescription(...)` 维护描述规则，但不提供任意 setter；
- 优先级通过 `PriorityPolicy` 计算并传入或在工厂中协作；
- 暂不重写 Entity 的 equals/hashCode，用 ADR 明确记录该决策将在 Week 03 结合哈希容器测试后完成；
- 不映射数据库，不添加框架注解。

### 测试要求

- 每个 VO 的合法、边界和非法创建；
- Priority 升级和封顶；
- 新工单必为 `CREATED`；
- null 的 id/设备/描述/优先级被拒绝；
- 外部无法任意改 id/status；
- Week 01 优先级组合仍通过。

## Lab 7：字符串与哈希思想（45—60 分钟）

输入限定为 ASCII 设备编码正文（不含前缀 `EQ-`），长度 4—12，只允许大写字母与数字。实现：返回第一个重复出现的字符；没有重复返回约定结果。

要求：

- 先写 `O(n²)` 双循环基线；
- 再用固定频次数组完成 `O(n)` 版本；
- 声明 ASCII 约束，遇到非法字符拒绝；
- 测试重复在开头/末尾、无重复、空、非法字符、大小写策略；
- 比较额外空间；
- 用伪代码解释如果字符集不受限，哈希表如何按 key 计数，正式 Java Map 留到 Week 03。

## Lab 8：AI 对抗审查（30 分钟）

模型完成后，让 AI 寻找“仍能通过公开 API 创建的非法状态”和“类比 TypeScript 导致的错误”。你负责：

- 逐条构造测试验证；
- 拒绝提前引入 Spring/JPA/Lombok 的建议；
- 拒绝完整状态机建议；
- 记录至少一个 AI 有效发现和一个越界建议。

## 总验收

- [ ] 所有类型职责表完成；
- [ ] 唯一状态词表完全一致，无别名；
- [ ] Value Object 与 Entity/DTO 能准确区分；
- [ ] 深层不可变故障可复现并修复；
- [ ] enum 不使用 ordinal；
- [ ] 模型没有框架依赖；
- [ ] 字符串算法含字符集边界和复杂度；
- [ ] 完成[无 AI 考核](./assessment.md)后再看答案。
