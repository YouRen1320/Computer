# Flexbox 独立练习（公开红灯）

修复 `answer.css` 与 `answer.json`；不要修改 oracle、预期红灯或验证脚本。目标是长文本可收缩、窄容器可换行、统一 gap，且 DOM/视觉/Tab 顺序一致。

```bash
./verify.sh
```

公开 starter 应稳定由 `./verify.sh` 以 41 退出；修复完成后同一命令以 0 退出并输出 `EXERCISE_GREEN`。部分修改、未知失败或基础设施异常以 43 退出。离线转绿后，真实浏览器 Flex overlay、Computed、连续 Tab 和视觉差分仍是必做但未由本目录自动验证的证据。
