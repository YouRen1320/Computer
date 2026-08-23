# 盒模型与定位独立练习（公开红灯）

修复 `answer.css` 与 `answer.json`，不要改 oracle、预期红灯或验证脚本。目标是让 300px border box、absolute badge、兄弟 stacking contexts 和 hidden/clip 对照都可手算。

```bash
./verify.sh
```

公开 starter 应稳定由 `./verify.sh` 以 41 退出；修复完成后同一命令以 0 退出并输出 `EXERCISE_GREEN`。部分修改、未知失败或基础设施异常以 43 退出。完成离线练习后仍需在真实浏览器保存 DevTools 盒模型、DOMRect、滚动条件和截图差分。
