# 公开练习：阻断维表重复导致的行爆炸

补全 `safe_enrich`，声明右侧设备维表必须唯一（many-to-one）。验收同时覆盖重复键拒绝、
正常 left join、matched/unmatched 标记、精确字段值和行数不变；仅仅“永远抛 MergeError”不能通过。
初始实现允许多对多并返回膨胀结果，因此 `./verify.sh` 固定失败。
