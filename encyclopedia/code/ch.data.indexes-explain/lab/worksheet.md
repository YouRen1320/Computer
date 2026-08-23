# 索引故障实验记录

运行前先预测：

1. 命中 85% 数据的 `status` 单列索引为何可能比顺序扫描读更多块？
2. 对“status 等值 + created_at 范围 + 稳定排序”，`(created_at, status)` 第一处可信浪费证据是什么？
3. `date(created_at)` 为什么不等于普通 `created_at` 搜索键？怎样改成半开区间？

每项记录固定查询、规模/分布、建前后结果指纹、estimated/actual rows、节点、Rows Removed、buffers、结论和回滚。不要把教学夹具中的块数当真实 PostgreSQL 测量。
