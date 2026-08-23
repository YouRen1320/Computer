# 南昌目标岗位市场样本（2026-07-11）

这是一份面向个人学习与求职决策的**可追溯快照**，不是南昌招聘市场普查。样本围绕当前学习路线分层检索：Java后端、Java+Vue全栈、Vue3/uni-app相邻前端、Python/AI应用。搜索词是人为分层的，因此**样本条数和岗位簇占比不能当作市场份额、岗位总量或录用概率**。

## 快速入口

- [原始岗位样本](./raw/job-postings.csv)：84条去重岗位，18个固定字段；
- [分析结论](./analysis.md)：岗位簇、技能、月薪、经验学历、行业与行动建议；
- [技能频率](./skill-frequency.csv)：只统计平台明确展示的技能标签；
- [来源与取证日志](./source-log.md)：检索时间、查询、清洗过程和证据等级；
- [四版简历映射](./resume-mapping.md)：R1—R4适用岗位、证据和缺口；
- [后续复采手册](./search-playbook.md)：低频、可重复的人工与脚本流程；
- [采集脚本](./scripts/collect.py)、[分析脚本](./scripts/analyze.py)、[验证脚本](./scripts/validate.py)。

## 这份数据能回答什么

它适合回答：

- 当前南昌公开样本中出现了哪些相邻岗位；
- 平台职位卡明确显示了哪些技能、经验、学历和薪资；
- 四版简历分别应该突出什么，哪些岗位不应误投；
- 学习计划中哪些能力应优先形成可验证项目证据。

它不能可靠回答：

- 南昌某技术的真实岗位总量或市场占比；
- 未显示在职位卡上的完整JD要求；
- 企业是否仍在招聘、是否为外包/驻场、实际工作强度和最终薪资；
- 你的录用概率。

## 证据口径

本快照84条全部来自智联招聘官方结构化搜索结果，每条均有官方岗位编号、唯一详情链接、发布时间和检索时间，`evidence_quality` 为 `official_structured_search_listing`。

这一级证据比普通搜索引擎摘要更结构化，但**仍不等于已人工打开并核验完整JD**。因此：

- `skills_raw` 仅保存平台职位卡标签；
- 没出现某技能不代表JD没有要求；
- 不从职位名称猜测具体版本、框架深度或工作职责；
- 投递前必须重新打开岗位页核实完整JD、公司、地点和有效性。

本批次没有使用 `search_snippet` 记录，也没有把聚合搜索页拆成多个虚构岗位。

## CSV字段

`raw/job-postings.csv` 严格按以下18列输出：

```text
sample_id,title,company,city,salary_min_k,salary_max_k,salary_period,
experience,education,industry,role_cluster,skills_raw,source_site,
source_url,published_or_updated,retrieved_at,evidence_quality,notes
```

薪资的 `salary_min_k` / `salary_max_k` 单位为人民币千元。只在原始职位卡能无歧义解析为月薪时填写；日薪、时薪、周薪、年薪和面议不强行换算。原始薪资文本保存在 `notes` 中。

## 复现与验证

在工作区根目录运行：

```bash
python3 job-market/scripts/analyze.py
python3 job-market/scripts/validate.py
```

采集脚本调用的是会变化的公开搜索接口，只应在需要复采时低频运行：

```bash
python3 job-market/scripts/collect.py
```

接口出现验证、限流或结构变化时应停止，不绕过访问控制。脚本不采集招聘者联系方式、头像或个人资料。复采会更新CSV、JSON汇总和技能频率，但不会自动重写本页、`source-log.md`、`analysis.md`、`resume-mapping.md` 等解释性文档；这些必须按新快照人工复核。

## 当前验收结果

```text
rows=84
columns=18
unique_ids=84
unique_urls=84
source_distribution={'智联招聘': 84}
evidence_quality={'official_structured_search_listing': 84}
cluster_distribution={'Vue3/uni-app前端': 15, 'Python/AI应用': 23,
                      'Java后端': 22, 'Java+Vue全栈': 24}
VALIDATION_OK
```

详细限制和正确解读方式见[分析结论](./analysis.md)。
