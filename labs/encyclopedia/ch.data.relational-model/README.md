# 实验：从宽表恢复关系图

目标：不写 DDL，先从固定宽表识别重复设备事实、冲突区域、行语义和关系方向，再用拆分后的设备/工单样例验证模型。

步骤：

1. 阅读 `worksheet.md`，先写预测。
2. 检查 `data/wide_work_order.csv`，找出 D-01 的重复和矛盾。
3. 阅读 `observations.json` 中的关系图答案。
4. 运行 `./verify.sh`。
5. 修改一项答案制造故障，保存第一条 `oracle-failure`，恢复后重跑。

验证完全离线，只读仓库内 CSV/JSON。
