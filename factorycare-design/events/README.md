# FactoryCare事件目录

本目录是跨模块/跨进程事件的唯一设计目录。所有事件按至少一次交付设计，消费者必须按`eventId`幂等；文件可解析不等于消息系统已经实现。

| 事件 | 生产模块 | 主要消费者 | 业务事实 |
| --- | --- | --- | --- |
| [WorkOrderCreated.v1](./work-order-created.v1.schema.json) | workorder | reporting、audit、可选AI分诊任务 | 报修已成功创建工单 |
| [WorkOrderAssigned.v1](./work-order-assigned.v1.schema.json) | workorder | engagement、reporting、audit | 派单已在核心事务提交 |
| [WorkOrderResolved.v1](./work-order-resolved.v1.schema.json) | workorder | reporting、audit | 技师已提交解决，尚未验证关闭 |
| [WorkOrderClosed.v1](./work-order-closed.v1.schema.json) | workorder | knowledge、reporting、audit | 工单已验证并关闭，可生成待审核草稿 |
| [KnowledgeDocumentPublished.v1](./knowledge-document-published.v1.schema.json) | knowledge | Python ingestion、audit | 某不可变知识版本已发布且可索引 |
| [KnowledgeDocumentRevoked.v1](./knowledge-document-revoked.v1.schema.json) | knowledge | Python ingestion、audit | 某知识版本已撤回且必须立即不可检索 |

## 演进规则

- `eventType`包含`.v1`且与Schema文件一致；
- envelope与payload允许出现未知可选字段；消费者只读取已知字段并忽略未知字段，不得把未知字段解释成命令、权限或默认业务行为；
- 只加入向后兼容的可选字段时可保持v1，新增生产者必须先验证现存消费者确实能忽略该字段；
- 删除字段、改变含义、改变单位或必填性时创建v2；
- payload只带消费者完成工作所需的最小事实，不复制整张数据库记录；
- 敏感文本优先传ID/摘要，消费者需要更多信息时调用授权API；
- eventType是唯一事件类型字段；不得并存type、name等第二套名称；
- 生产事务同时写`outbox_event`，外部发送失败不能回滚已提交业务；
- 事件时间是事实发生时间，不是消费者处理时间；
- 消费失败进入有限重试与人工恢复，不承诺Exactly Once。

## 禁止新增的隐式事件

`SlaBreached.v1`、`NotificationSent.v1`等事件如果未来需要，必须先进入`PROJECT_SPEC.md`与本目录，再实现生产/消费；当前不能因为写代码方便而临时发出未治理事件。
