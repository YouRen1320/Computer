# MyBatis 故障诊断实验

本实验固定五条 FactoryCare 故障链：参数路径错名、resultMap 列错配、无条件时悬空 WHERE、排序文本替换和 N+1。先在 `worksheet.md` 写预测，再运行：

```sh
./verify.sh
```

输出证明故障输入、首个失败层、修复和查询预算之间的关系。它是离线诊断模型；真实验收还要在 Boot/MyBatis/PostgreSQL 中保存 mapper 日志、最终 SQL、SQLSTATE 和修复后重跑证据。
