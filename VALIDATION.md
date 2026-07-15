# 学习资产冲刺验收记录

- 最终执行：2026-07-11 13:56 CST
- 结论：`PASS`
- 范围：[SPRINT_SCOPE.md](./SPRINT_SCOPE.md)中已确认的教学包、岗位证据、FactoryCare设计、学习教练与总体验收

`PASS`表示本轮定义的结构、契约、一致性和证据检查通过，不表示用户已经学会、FactoryCare已经实现或外部岗位仍然有效。

## 最终结果

| 资产 | 最终规模 | 已验证结果 |
| --- | ---: | --- |
| Week 00—06教学包 | 42个Markdown，7,849行 | 7周×6文件、评分六类、算法/复杂度、链接、围栏、考试/答案/面试校准分离通过 |
| 南昌岗位快照 | 84行×18列；12个资产文件 | 84个唯一ID、84个唯一URL、4岗位簇、81条可解析月薪；来源等级和样本局限完整 |
| FactoryCare设计 | 29个文件 | 66条公共路径/78个操作/107个Schema；7条内部路径/操作；47个数据实体、43个权限、93个验收ID、9个ADR、6个事件 |
| 学习教练Skill | 6个文件 | 官方`quick_validate.py`通过；进度检测推断Week 00；老师模式与考试防泄题前向测试通过 |
| 总体文档 | 120个Markdown | 659个总体验证项通过；本地链接和代码围栏通过 |

## 可复现命令

在工作区根目录执行：

```bash
ruby scripts/validate-learning-assets.rb
```

最终关键输出：

```text
markdown_files: 120
checks: 659

[PASS] FactoryCare design
PASS: 1360 checks, 6 event schemas, 2 OpenAPI documents

[PASS] Nanchang job snapshot
rows=84
columns=18
unique_ids=84
unique_urls=84
VALIDATION_OK

[PASS] Learning coach Skill
Skill is valid!

[PASS] Progress detector
current_week=00

VALIDATION_OK
```

也可分别运行：

```bash
ruby factorycare-design/scripts/validate-design.rb
python3 job-market/scripts/validate.py
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  ~/.codex/skills/factorycare-learning-coach
ruby ~/.codex/skills/factorycare-learning-coach/scripts/check_progress.rb \
  --workspace /Users/youren/Desktop/Study/Computer --json
```

进度检测的唯一警告是“尚无进行中周，因此从第一个未完成项推断Week 00”。这与[PROGRESS.md](./PROGRESS.md)仍为真实的“未开始”状态一致，不是错误，也没有被自动改写。

## 独立审计与修复链

### 教学内容审计

独立审计最初发现并修复：非法设备编码fixture、已经存在的枚举现场题、`ATOMIC_MOVE`可移植语义、Stream `count()`阶段消除、评分结构、面试答案混放、状态类型漂移、不可稳定复现的`String ==`故障、Unicode空白、Flutter补丁和Week 06时间预算等问题。

修复后的另一轮独立审计又找到并清理：Week 04—06评分名称残留、Week 06一个无真实变更的候选题，以及另一个候选题缺少答案校准。最终确认5个Week 06现场候选都有独立校准，42文件结构/链接/围栏和答案隔离通过。

### 设计语义审计

独立审计最初发现并修复：3个不可满足的组合Schema、匿名二维码安全继承、错误的状态数量、状态机命令缺口、知识审核/AI/报表/CSRF/失败契约缺口、核心审计事务矛盾、事件兼容和共享基础设施所有权等问题。

第一次修复后再次审计仍发现3个P1：审批枚举冲突、附件归属与知识对象冲突、TEAM数据范围不可落地。最终目标态统一为：

- 审批命令`APPROVE|REQUEST_CHANGES`，持久状态`PENDING|APPROVED|CHANGES_REQUESTED`；
- 上传`purpose=REPORT_CREATION|REPORT_SUPPLEMENT|WORK_ORDER`，最终附件owner仅`REPORT|WORK_ORDER`，知识对象只归`knowledge_version`；
- team成为organization下的显式实体，并贯通membership、TEAM scope、assignment、reassignment和公共API。

终审结论为无剩余P0/P1，专项验证器通过1,360项检查。

### 学习教练前向测试

- 老师模式：只读取进度、Week 00计划、教学README和所需概念，正确推断Week 00，给出一个预测题作为下一动作；
- 无AI考试模式：读取`assessment.md`但未读取或搜索`answers.md`，拒绝中途核对答案，只允许“继续考试”或“作废并切换教学”。

## 已验证与未验证的边界

### 已验证

- YAML/JSON/CSV可解析，CSV列宽与唯一标识符合规则；
- OpenAPI内部引用、重复键、必要操作、状态/事件/模块、CSRF、幂等、常见失败响应、内部服务路由和关键组合Schema静态检查通过；
- 事件文件集合、名称、`eventType`、版本、actor/team与新增可选字段兼容策略一致；
- Markdown本地链接、代码围栏、教学结构、答案隔离和关键回归模式通过；
- 岗位样本行数、字段、URL格式、日期窗口、岗位簇和汇总数量一致；
- Skill结构、manifest、只读进度检测和两个代表性行为测试通过。

### 未验证

- 教学代码是片段/实验骨架，没有作为完整Maven工程编译；
- 未使用独立OpenAPI标准校验器生成并编译TypeScript/Dart客户端，也未用独立JSON Schema 2020-12引擎验证实例；
- 未实现或运行Spring、PostgreSQL迁移、模块测试、鉴权/CSRF、幂等/并发、对象存储、Redis、离线同步、Python AI或安全渗透测试；
- 84条岗位是单一平台的结构化职位卡，没有逐条人工核验完整JD、公司质量或当前有效性；
- 版本口径在进入对应学习周时仍需复核最新稳定patch；
- 文档生成、考试题存在和验证脚本通过都不能证明用户已经掌握相关能力。

## 兼容性与破坏性修正

没有为错误旧草案保留兼容别名或双重语义；这是有意选择长期可维护目标态，而不是兼容性妥协。主要破坏性设计修正包括：

- 二维码从URL路径参数改为匿名POST body；
- 知识撤回改为显式revocation命令；
- 附件从旧`ownerType`收敛为上传purpose与最终business owner两层；
- 指派/转派和`WorkOrderAssigned.v1`明确team；
- 审批词汇、事件actor和错误响应统一。

当前没有业务实现或已部署消费者，因此未建立迁移兼容层。若未来已有按旧草案生成的客户端、fixture或消费者，必须重新生成客户端、迁移字段/事件并按影响顺序部署；不能同时长期保留两套契约。

## 刻意未做

- 未提前实现完整FactoryCare业务代码或安装后续阶段环境；
- 未修改学习进度、伪造小时/分数/掌握状态；
- 未提交简历、投递岗位或联系招聘方；
- 未扩展Week 07—36同等深度教学包；
- 未把React、微服务、Kafka、Kubernetes、多Agent或算法岗加入本轮主线。
