# Week 05 实验手册

先完成集合选择表，再写实现。所有生产练习使用显式循环，Stream 留到 Week 07。每个返回集合都要标明：顺序、重复、可修改性、是否快照、元素是否深拷贝。

## Lab 1：访问模式到集合（75 分钟）

为以下场景选择抽象与实现，并说明至少一个被拒方案：

1. 按首次出现顺序去重工单 id；
2. 按设备 id 快速查设备；
3. 技师待处理命令先进先出；
4. 保留工单创建顺序且允许相同优先级；
5. 判断设备编码是否已存在；
6. 从两端处理离线同步重试队列。

### 验收

- 不只写实现类名，还写顺序/唯一/查找语义；
- 复杂度注明“平均/摊销/最坏”边界；
- 不以 null 能力作为业务设计理由。

## Lab 2：equals/hashCode 正反实验（90 分钟）

### Value Object

验证两个规范值相同的 `EquipmentCode`：

- `equals` 为 true；
- hashCode 相同；
- 放入 HashSet 后只保留一个；
- 作为 HashMap key 可由另一个等值实例查到。

### Entity

将 `Equipment` 和 `WorkOrder` 设为 final，基于稳定 id 实现 equals/hashCode。验证名称、描述、优先级变化不会改变哈希查找。

### 可变 key 故障

创建一个错误类型，把可变 name 同时放入 equals/hashCode：

1. 放入 HashSet；
2. 修改 name；
3. 观察 contains/remove 异常行为；
4. 修为稳定 id；
5. 保存失败测试和解释。

不要把故障类型留在正式模型。

## Lab 3：只读视图不是快照（60 分钟）

用可变源 List 对比：

- 直接返回源；
- `Collections.unmodifiableList(source)`；
- `List.copyOf(source)`。

从调用方修改返回值、从仓储内部修改 source，观察差异。再对 `Map<EquipmentId,List<WorkOrder>>` 验证只冻结外层为何不足。

### 验收

- 能用测试证明时间点结构快照；
- 明确元素实体仍可能共享引用；
- 对嵌套容器逐层冻结。

## Lab 4：泛型 `PageResult<T>`（75 分钟）

设计最小泛型结果：

- `items` 为不可修改结构快照；
- `pageNumber >= 0`；
- `pageSize > 0`；
- `totalElements >= 0`；
- 内容类型可分别为 Equipment 与 WorkOrder；
- 不创建完整分页查询框架。

写一个泛型方法把 `Collection<? extends T>` 复制为 `List<T>`，解释为何是 extends。再写一个把元素加入 `Collection<? super T>` 的最小例子，解释为何是 super。

### 故障检查

- raw `PageResult`；
- `List<Equipment>` 强转成 `List<Object>`；
- 构造后修改原 items；
- items 中元素可变与结构不可变的边界。

## Lab 5：Comparator 与稳定顺序（60—75 分钟）

对一组 WorkOrder 实现：

1. Priority 明确业务 rank；
2. 优先级降序；
3. 同优先级保持创建/插入顺序；
4. 排序结果是新结构，不修改仓储内部顺序；
5. 不使用 enum ordinal。

测试：四种优先级、同级三项、空/单项、排序后实体相等性不变。

## Lab 6：FactoryCare 内存仓储（3—4 小时）

### 接口契约

`EquipmentRepository`：

- 保存新设备；
- 按 `EquipmentId` 查询；
- 判断 `EquipmentCode` 是否存在；
- 返回插入顺序结构快照。

`WorkOrderRepository`：

- 保存新工单；
- 按 `WorkOrderId` 查询；
- 返回插入顺序结构快照。

本周契约规定：重复 id 拒绝；设备 code 重复也拒绝；查询不存在返回 `Optional.empty()`；不支持更新、并发和事务。

### 实现约束

- 内部可用 `LinkedHashMap`；
- 不返回内部 Map、`values()` 视图或可变 List；
- 错误信息包含冲突字段但不泄漏敏感信息；
- 不创建万能 BaseRepository；
- 无 Spring 注解和数据库代码。

### 查询服务

建立一个纯 Java 查询服务：

- 列出全部工单结构快照；
- 按优先级降序并保持同级创建顺序；
- 按设备 id 分组“未关闭”工单；
- 未关闭定义为状态不是 `CLOSED` 且不是 `CANCELLED`；
- 使用现有唯一状态词，不创建任何近义状态。

Week 18 前没有完整状态转换 API。查询测试中的非 `CREATED` 状态只能通过测试 fixture 表示“已存在的历史样本”；如果现有 WorkOrder 无安全 fixture，使用只读 `WorkOrderSnapshot`（id、equipmentId、status、priority、creationSequence）作为查询输入。不要给领域实体增加 public `setStatus`，也不要把 fixture 当作合法流转证明。

### 测试矩阵

- 首次保存与按等值 id 查询；
- 重复 id；
- 重复设备 code；
- 不存在 id；
- 保存后修改调用方临时集合不影响仓储；
- 调用方不能增删 `findAll` 结果；
- 多次 `findAll` 不共享可变容器；
- 优先级排序及同级稳定；
- `CLOSED/CANCELLED` 被排除，其他现有状态保留。

## Lab 7：双指针（45—60 分钟）

对一个已按升序排列的严重度数组原地去重，返回唯一前缀长度。

要求：

- null 策略明确；
- 空、单元素、全同、全不同、连续重复、多段重复；
- 验证有效前缀，不断言尾部废弃区域；
- 写 `read/write` 不变量；
- 时间 `O(n)`，额外空间 `O(1)`；
- 明确输入必须有序且方法会修改输入。

故障注入：`write` 初始值错误、从 read=0 开始错误比较、返回 `write` 而不是有效长度。让测试分别捕获。

## Lab 8：AI 代码审查（30 分钟）

让 AI 只审当前 diff，重点找：raw type、错误通配符、可变 key、内部集合泄漏、比较器 ordinal 和嵌套快照。你必须为每个采纳项写失败测试；没有可执行证据的建议标为推测。

## 总验收

- [ ] 集合选择有业务语义和复杂度；
- [ ] equals/hashCode契约有正反测试；
- [ ] 视图/快照/深拷贝能区分；
- [ ] 泛型无raw type和无理由强转；
- [ ] 仓储契约、重复行为和缺失行为明确；
- [ ] 唯一状态词表未被破坏；
- [ ] 双指针有前提、不变量和复杂度；
- [ ] 完成[无 AI 考核](./assessment.md)。
