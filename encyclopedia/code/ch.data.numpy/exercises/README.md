# 公开练习：按日期聚合时长

补全 `mean_per_day`：输入 shape 为非空 `(technician, day)`，应沿 technician 轴忽略 NaN
求每日均值；一维输入及任一轴为空时必须抛 `ValueError`。初始实现选错 axis 且未验证 shape，
因此 `./verify.sh` 固定失败。
