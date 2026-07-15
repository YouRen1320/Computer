# Week 00—06 深度教学包

这些教学包把[逐周计划](../weeks/README.md)的目标展开为可教学、可练习、可考试、可面试追问的材料。它们是学习工具，不代表对应周已经完成；真实状态只记录在[PROGRESS.md](../PROGRESS.md)。

## 每周六件套

| 文件 | 用途 | 使用规则 |
| --- | --- | --- |
| `README.md` | 前置、时间、成果、执行顺序与过关证据 | 每周先读 |
| `concepts.md` | 概念、心智模型、TS/Vue类比及类比失效 | 按当天主题读，不要求一次背完 |
| `labs.md` | 最小实验、故障注入和FactoryCare增量 | 先预测，再运行，再修改 |
| `assessment.md` | 无AI考核题与提交格式 | 考试时只打开此文件 |
| `answers.md` | 参考答案、评分依据和常见错误 | 提交后或明确放弃考试完整性后才打开 |
| `interview.md` | 面试主问、追问与回答评价点 | 一次只问一题，结束后复盘 |

## 入口

| 周次 | 主题 | 教学包 |
| --- | --- | --- |
| Week 00 | 环境、基线、岗位采样与AI协作 | [开始](./week-00/README.md) |
| Week 01 | Java语法、类型、控制流、JUnit与数组 | [开始](./week-01/README.md) |
| Week 02 | OOP、record、enum、值对象与字符串 | [开始](./week-02/README.md) |
| Week 03 | 集合、泛型、equals/hashCode与双指针 | [开始](./week-03/README.md) |
| Week 04 | 异常、I/O、时间、JSON与链表 | [开始](./week-04/README.md) |
| Week 05 | Lambda、Stream、Optional、栈与队列 | [开始](./week-05/README.md) |
| Week 06 | 并发、虚拟线程、JVM、排序与二分 | [开始](./week-06/README.md) |

## 推荐学习回路

1. 从周README选一个20—45分钟结果；
2. 先说已有理解，再读对应概念；
3. 运行实验前预测输出、异常或复杂度；
4. 完成最小实现后主动制造一个失败并解释证据；
5. 关闭笔记口述60—120秒；
6. 到规定时段完成无AI考核，提交后再批改；
7. 把实际小时、分数与交付链接写入进度表，未达到门槛则做窄范围补考。

## 使用专属学习教练

个人Codex Skill安装在[factorycare-learning-coach](/Users/youren/.codex/skills/factorycare-learning-coach/SKILL.md)。新任务中可以直接说：

```text
使用 $factorycare-learning-coach，判断我当前是第几周，按老师模式带我开始今天的学习。
```

也可以明确请求“苏格拉底提示”“代码审查”“无AI考试”“批改”“模拟面试”或“周复盘”。考试模式会禁止读取答案册；批改只有在提交答案或明确要求揭示后才读取相应答案。

## 边界

- 当前深度包只覆盖Week 00—06；Week 07—36仍以[逐周计划](../weeks/README.md)为准，不能假装已有同等材料；
- 示例是实验骨架，不是已编译、已部署的完整FactoryCare实现；
- JDK和依赖进入实际周次时仍应按[版本策略](../TECH_STACK.md)复核当前稳定patch；
- 生成代码可以加速练习，但过关仍要求本人能解释、修改、测试与排错。
