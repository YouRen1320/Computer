# Week 00—08 兼容实践与考核包

这些教学包保留 Java 准备周和语言阶段的实践、考核、答案与面试追问。重复概念讲义已经迁移为[百科章节](../book/README.md)适配页，避免两份正文继续漂移。材料存在不等于已学习；真实状态只记录在 [PROGRESS.md](../PROGRESS.md)。

## 每周六件套

| 文件 | 用途 | 使用规则 |
| --- | --- | --- |
| `README.md` | 前置、顺序、成果和过关证据 | 每周先读 |
| `concepts.md` | 当前周到权威百科章节的链接 | 教师必须继续读取链接章节正文 |
| `labs.md` | 完整上下文、最小实验、故障注入和项目增量 | 先预测，再运行，再修改 |
| `assessment.md` | 无 AI 考核题与提交格式 | 考试时只打开此文件 |
| `answers.md` | 参考答案、评分依据和常见错误 | 提交后或明确放弃考试完整性后读取 |
| `interview.md` | 主问、追问与回答评价点 | 一次只问一题 |

## 入口

| 周次 | 主题 | 教学包 |
| --- | --- | --- |
| Week 00 | 环境、基线、Git、项目词汇与 AI 边界 | [开始](./week-00/README.md) |
| Week 01 | 程序结构、I/O、类型、运算、方法与 JUnit | [开始](./week-01/README.md) |
| Week 02 | String、null、数组、条件、循环与方法设计 | [开始](./week-02/README.md) |
| Week 03 | 类、对象、构造器、封装、static 与 final | [开始](./week-03/README.md) |
| Week 04 | 继承、接口、抽象、多态、组合、record 与 enum | [开始](./week-04/README.md) |
| Week 05 | 集合、泛型、equals/hashCode | [开始](./week-05/README.md) |
| Week 06 | 异常、I/O、时间与 JSON | [开始](./week-06/README.md) |
| Week 07 | Lambda、Stream 与 Optional | [开始](./week-07/README.md) |
| Week 08 | 并发、虚拟线程、JVM 与 G1 | [开始](./week-08/README.md) |

## 推荐学习回路

1. 从周 README 选择一个 20—45 分钟可验证结果；
2. 先说已有理解，再读对应概念；
3. 面对完整代码预测输出、错误阶段或状态变化；
4. 完成最小实现后主动制造一个失败；
5. 关闭笔记复述 60—120 秒；
6. 在规定时段完成无 AI 考核，提交后再批改；
7. 只把真实小时、分数和证据写入进度表。

## 边界

- 当前实践与考核包只覆盖 Week 00—08；Week 09—48 直接使用章节配套的 example/lab/exercise，不能假装已有同等答案册；
- 示例是实验和考核材料，不是已实现的完整 FactoryCare；
- 版本进入实际周次时按 [TECH_STACK.md](../TECH_STACK.md) 重新核对稳定补丁；
- AI 可帮助讲解和生成练习，但通过仍要求本人能解释、修改、测试和排错。
