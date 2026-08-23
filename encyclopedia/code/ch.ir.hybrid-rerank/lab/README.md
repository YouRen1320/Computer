# 实验：四组检索消融与延迟预算

实验在同一冻结查询集上比较 sparse、dense、RRF hybrid 与 scripted reranker 四组排名，保存逐查询 nDCG、平均值和受控延迟预算。重排器只是确定性评分夹具，不是已验证模型；延迟也是预算夹具，不是墙钟测量。

```bash
./verify.sh
```

没有启动 PostgreSQL/pgvector，没有加载真实重排模型，也没有生成生产质量或延迟证据。FactoryCare 的工单、ACL、状态机仍由 Java 所有；Python 检索投影和排名可以重建，候选必须在融合和重排前受当前授权集合约束。
