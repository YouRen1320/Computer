# Week 03 实验手册

## Lab 1：对象与引用（60 分钟）

创建两个 Device 与三个引用：两个引用指向同一对象，一个指向另一对象。修改名称并画出引用图。预测 `==`，暂不自定义 equals。

故障：null reference 调方法；从 stack trace 找业务行。

## Lab 2：构造器与有效创建（90 分钟）

为 Device 编写 id/name 构造器：null/blank 失败，enabled 初始 true。再加命名 static factory `createEnabled`，比较是否真的增加价值。

故障：误写 `void Device(...)`；观察为何 `new Device(...)` 找不到构造器。

## Lab 3：从 setter 到行为（90 分钟）

反例有 public fields/setStatus/setAssignee。重构：

- private fields；
- `rename`、`disable`、`assignTo`；
- 非法行为抛明确异常；
- 测试外部不能随意改字段（用编译或 API 审计）。

## Lab 4：static 测试污染（60 分钟）

建立 mutable static `createdCount`，让两个测试顺序不同出现失败；移除业务共享或明确 reset 仍分析风险。说明为什么 Spring 单例也不等于把用户状态放 static。

## Lab 5：final 与防御性复制（75 分钟）

Checklist 接收 String[]：

1. 直接保存后修改输入，观察内部变化；
2. 构造时复制；
3. getter 直接返回后再泄漏；
4. 返回复制；
5. 说明复制 O(n) 时间/空间。

## Lab 6：FactoryCare Device/WorkOrder（4—5 小时）

### Device

- id/name 创建校验；
- enabled 初始 true；
- disable 重复行为契约；
- rename 校验。

### WorkOrder

- number/deviceId/description/priority；
- assignee 初始可为空，但通过 `assignTo` 设置；
- 重复分配/空技师契约；
- 工单号与设备 ID 创建后不变；
- 不提供通用 status setter（状态 enum/完整状态机留后）。

测试正常/非法/重复/异常后状态。两个对象实例状态互不污染。

## Lab 7：AI 对抗审查（45 分钟）

让 AI 生成一个 DTO 风格 WorkOrder，逐项标注：public setter、不变量、static、null、泄漏、框架耦合。只采纳有证据的修改。

## Lab 8：关闭 AI 修改（60—90 分钟）

为 Device 增加 serialNumber：创建时规范化、非空、之后不可变。更新构造、行为/查询、测试，不重写全部类。

## 完成清单

- [ ] 引用图与 null 故障；
- [ ] 构造器和不变量；
- [ ] setter→行为重构；
- [ ] static 污染证据；
- [ ] 防御性复制 O(n)；
- [ ] Device/WorkOrder 测试；
- [ ] 独立字段/规则变化。
