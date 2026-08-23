# Worksheet：AI 候选补丁审查记录

姓名 / 日期：____________________

## 1. 任务边界

- Goal：
- 必要 Context：
- 明确不发送的 Context：
- 可修改路径：
- 禁止动作：
- Done when：
- 回滚触发条件：

## 2. 补丁前预测

| 检查 | 预测 | 若预测错误，最先看什么 |
| --- | --- | --- |
| baseline-regression |  |  |
| requested-feature |  |  |
| unsafe task brief |  |  |

## 3. 逐 hunk 审查

| 候选 / hunk | 作用域 | 权限与副作用 | 隐私 | 依赖与许可证 | 测试影响 | 决定与理由 |
| --- | --- | --- | --- | --- | --- | --- |
| accepted-zero-fix / h1 |  |  |  |  |  |  |
| rejected-hidden-network / h1 |  |  |  |  |  |  |
| rejected-delete-negative-test / h1 |  |  |  |  |  |  |
| rejected-delete-negative-test / h2 |  |  |  |  |  |  |
| rejected-fabricated-success / h1 |  |  |  |  |  |  |
| rejected-unlicensed-dependency / h1 |  |  |  |  |  |  |

## 4. 主张—证据矩阵

| 主张 | 独立检查 | expected | actual | 结论 / 未验证边界 |
| --- | --- | --- | --- | --- |
| “所有测试均通过” |  |  |  |  |
| “没有网络副作用” |  |  |  |  |
| “负数行为未退化” |  |  |  |  |
| “依赖许可证没问题” |  |  |  |  |
| “拒绝项没进入工作树” |  |  |  |  |

## 5. 故障诊断

- 隐藏网络请求的第一处可信证据：
- 删除负测的第一处可信证据：
- 伪造成功日志与 oracle 冲突的证据：
- 为什么不能通过修改 expected 消除失败：

## 6. 接受、复跑与回滚

- 接受候选 ID：
- 接受前基线摘要：
- 接受后摘要：
- 两套 oracle 结果：
- 回滚后摘要：
- 回滚后 baseline-regression：
- 回滚后 requested-feature 及其为什么应失败：
- 两次评审报告摘要是否相同：

## 7. 120 秒复述提纲

用“AI 是候选生成器，不是事实、权限或证据来源”开头，覆盖 prompt scope、秘密与私有数据、权限边界、diff 审查、主张证伪、测试与回滚，并给出一个会失败的反例。
