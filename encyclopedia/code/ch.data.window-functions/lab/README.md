# 窗口、分区、排序与 frame 故障实验

先填写 `worksheet.md`，再运行 `./verify.sh`。实验用两组并列时间同时放大三类故障：漏 PARTITION、窗口 ORDER BY 无唯一 tiebreaker、默认 peer-aware frame 导致累计突跳。

oracle 独立计算正确值和破坏性改写的预言，且检查输出行数仍为六。它不执行 PostgreSQL，也不验证计划或性能。
