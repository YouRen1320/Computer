# 实验：焦点陷阱、空名称与 ARIA 状态漂移

本目录保留修复后的无障碍表单基线，并记录三类故障的注入、首证据、修复与同任务重跑。先运行离线验证，再在副本中逐一破坏；不要修改预期矩阵迎合故障。

```bash
./verify.sh
```

唯一验证器不会执行 JavaScript/按键/读屏。真正完成 lab 必须在目标环境按 `audit-matrix.json` 记录 Tab/Shift+Tab、Accessibility name/state、错误摘要焦点与播报；JSON 中三类 `real_*_observed` 在离线仓库保持 false。
