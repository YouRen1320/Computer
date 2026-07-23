# 实验：列表重排时让 State 跟随业务项

`reconciliation.yml` 模拟同一父节点下两个同类型 StatefulWidget。验证器比较无 key 与使用工单 ID 作为 `ValueKey` 时的状态归属。

运行 `./verify.sh`。实验应证明：无 key 时状态按位置复用，稳定 key 时状态按业务 ID 迁移。
