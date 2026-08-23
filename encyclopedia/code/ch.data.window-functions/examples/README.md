# 窗口函数可运行示例

`query.sql` 保留六张工单，按技师分区，以创建时间和工单 ID 稳定排序，计算组内序号、前后工单、前后间隔和显式 ROWS 累计完成数。

运行 `./verify.sh`。oracle 从 CSV 独立手算每行预言并静态核对 SQL 合同；它不会连接 PostgreSQL。
