# RRF 手算示例

示例融合两条不可直接比较分值的候选排名，只使用名次计算 Reciprocal Rank Fusion，并在融合前应用 Java 授权路径给出的允许文档集合。

```bash
./verify.sh
```

这里没有调用 pgvector 或重排模型；通过只说明 RRF 算式、去重和 ACL 过滤夹具正确。
