# 可手算的向量距离与精确排名

本示例用二维向量手算欧氏距离、内积和余弦距离，并验证同一 Embedding 空间内的精确排序。

```bash
./verify.sh
```

它没有启动 PostgreSQL、没有创建 pgvector 索引，也没有产生真实 `EXPLAIN` 或延迟证据；通过只说明数学夹具正确。
