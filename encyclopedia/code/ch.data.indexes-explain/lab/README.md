# 索引故障注入实验

`scenarios.json` 固定三项故障：低选择性单列索引、复合列顺序不匹配、函数包住索引列。先填写 `worksheet.md` 的预测，再执行 `./verify.sh`。

oracle 验证诊断证据和修复方向，不连接 PostgreSQL，也不声称夹具块数来自真实服务器。
