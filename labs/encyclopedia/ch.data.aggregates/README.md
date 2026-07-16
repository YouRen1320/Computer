# 聚合故障实验

实验验证总数闭合、空输入、NULL 分组/时长、HAVING 阈值两侧，并注入：未分组列、WHERE 中 aggregate、把 `COUNT(duration_minutes)` 错当事件总数。

运行 `./verify.sh`。所有观察来自固定 CSV，不连接数据库。
