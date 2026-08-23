# FactoryCare 聚合不变量实验

实验以十二条断言固定实体身份、值对象 normalization、精确状态集合、主路径七条转换，以及 repeated triage、过早 assign/start/close 的无副作用拒绝。

先记录每个命令的 before/after snapshot，再运行 `./verify.sh`。本实验不声称覆盖完整 12×12 状态矩阵、持久化 compare-and-swap 或事务原子性。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
