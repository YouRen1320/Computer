# CSS 层叠独立练习（公开红灯）

修复 `answer.css` 与 `answer.json`，不要修改 oracle、预期红灯或验证脚本。目标是用显式 layer、低权重边界、继承和可预测源码顺序表达覆盖，不使用 `!important` 或脆弱 ID 长链。

```bash
./verify.sh
```

公开 starter 应稳定由 `./verify.sh` 以 41 退出；修复完成后同一命令以 0 退出并输出 `EXERCISE_GREEN`。部分修改、未知失败或基础设施异常以 43 退出。完成后的答案还必须在真实浏览器中核对 computed style 与禁用规则后的视觉差异，离线 oracle 不代替该步骤。
