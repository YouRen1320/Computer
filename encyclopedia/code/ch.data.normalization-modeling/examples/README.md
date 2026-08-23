# 规范化可运行示例

`wide.csv` 含设备与技师重复事实，`model.json` 声明三张 3NF 关系、候选键和外键。运行 `./verify.sh`；oracle 独立分解并逐列重建原多重集合，不连接 PostgreSQL。
