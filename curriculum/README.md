<!-- GENERATED: factorycare-curriculum; DO NOT EDIT -->
# FactoryCare 编程百科课程架构

本目录由 canonical specs 确定性生成。当前 edition 为 `2026.2-draft`，目标与实际均为 255 章。目录和 placeholder 不是学习完成证据。

## 规范输入

- [Edition policy](edition.yml)
- [Volumes](volumes.yml)
- [Capabilities](capabilities.yml)
- [Topics](topics.yml)
- [Chapter spec contract](chapters/README.md)
- [Route plans](route-plans/README.md)
- [Migration ledger](migrations/README.md)

## 生成物

- [课程目录](catalog.yml)
- [概念与依赖图](concept-graph.md)
- [阶段门 G0—G8](gates.yml)
- [零基础路线](routes/zero-base.yml)
- [48 模块加速路线](routes/accelerated-48.yml)
- [FactoryCare 项目路线](routes/factorycare-project.yml)
- [非线性参考索引](routes/reference.yml)

## 命令

```bash
ruby scripts/generate-curriculum.rb --plan
ruby scripts/generate-curriculum.rb --check
ruby scripts/generate-curriculum.rb --write
ruby curriculum/validate_catalog.rb
```
