# FactoryCare 编程百科课程架构

本目录只定义课程的唯一事实源，不宣称正文已经完成。当前版共 170 章，全部为 `planned`。

## 五种不同语义

- `prerequisites`：没有先验证就不能安全开始本章的硬前置；参与 DAG、能力首用和有序路线检查。
- `recommended_after`：为了阅读连贯而推荐在其后学习；不等于硬依赖，也不能提供豁免证据。
- `teaches_capabilities` / `uses_capabilities`：验证隐藏前置；每项能力必须先教后用，且教师章可从使用章的硬前置闭包到达。
- 路线：零基础、有证据豁免的 48 模块、FactoryCare 业务垂直路线、非线性参考索引各有不同规则。
- G0—G8：与 `ASSESSMENTS.md`、`PROGRESS.md` 对齐的阶段门；文档存在或命令退出 0 都不会自动过关。

## 权威文件

- [课程目录](catalog.yml)
- [概念与依赖图](concept-graph.md)
- [阶段门 G0—G8](gates.yml)
- [零基础路线](routes/zero-base.yml)
- [48 模块加速路线](routes/accelerated-48.yml)
- [FactoryCare 项目路线](routes/factorycare-project.yml)
- [非线性参考索引](routes/reference.yml)
- [P1 目录对抗审查](review-p1.md)

运行 `ruby curriculum/validate_catalog.rb` 执行结构、语义、版本、路线、关卡、链接和占位校验。
