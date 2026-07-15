# Week 04 实验手册

## Lab 1：重载与重写（75 分钟）

建立父/子 policy、两个 overload，分别用父类型引用指向子对象。预测每次调用选择，再运行。加入 static 同名方法观察它不是实例动态分派。

## Lab 2：LSP 故障（60 分钟）

父策略允许 priority 1—5，子策略拒绝 1—3。用父类型参数的调用者测试证明替换失败。修复为组合/独立策略契约。

## Lab 3：interface 与 fake（75 分钟）

定义 `NotificationSender`，实现 `RecordingNotificationSender`。AlertService 只依赖接口；测试发送内容而不调用外部短信。

## Lab 4：组合替代继承（90 分钟）

把 `SafetyWorkOrder extends WorkOrder` 反例改为 WorkOrder 组合 PriorityPolicy/Category。比较实现成本、迁移、风险、回滚和长期维护。

## Lab 5：record/enum/sealed（90 分钟）

- WorkOrderId record 自校验；
- Priority enum 有稳定 level/code；
- sealed `PolicyResult` 表达 applied/notApplicable/invalid；
- switch 穷尽；
- record 内数组/List 浅不可变故障与复制。

## Lab 6：FactoryCare 策略与端口（4—5 小时）

- `PriorityPolicy` 接口；
- Default/Safety/StoppedMachine 三个策略，选择规则集中；
- `NotificationSender` 端口+recording fake；
- `WorkOrderId/DeviceId` 值对象；
- `Priority` enum；
- WorkOrder 保持 entity class；
- 测替换、分派、非法值、浅不可变、sender 失败边界。

扫描 k 个策略最坏 O(k)，空间 O(1)（不计预先持有策略列表）。先保持 k 小且顺序明确。

## Lab 7：故障注入（60 分钟）

1. 删除 `@Override` 并拼错参数形成 overload；
2. enum switch 漏一个值；
3. record 保存可变数组不复制；
4. sender 异常时错误地回滚已完成纯内存业务状态，讨论边界（真正事务在后续）。

## Lab 8：关闭 AI 新策略（60—90 分钟）

新增 `LongWaitingPolicy`：>=24 小时至少 3；只新增实现、装配/顺序和测试，不修改其他策略内部。

## 完成清单

- [ ] 重载/重写/静态分派预测；
- [ ] LSP 失败证据；
- [ ] interface fake；
- [ ] 继承→组合重构；
- [ ] record/enum/sealed 与浅复制；
- [ ] FactoryCare 策略/端口；
- [ ] 独立新策略。
