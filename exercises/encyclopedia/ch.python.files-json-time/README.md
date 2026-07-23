# 公开练习：严格解析事件时刻

补全 `parse_instant`：拒绝不带偏移的时间，并把合法 aware 时间规范化为 UTC。初始实现会错误接受 naive 值，因此 `./verify.sh` 固定失败。
