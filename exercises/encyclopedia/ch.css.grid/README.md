# Grid 独立练习（公开红灯）

修复 `answer.css` 与 `answer.json`，不要修改 oracle、预期红灯或验证脚本。目标是两列明确区域、`minmax(0,1fr)` 内容轨、允许且定尺寸的隐式行，以及不破坏任务顺序的 sparse placement。

```bash
./verify.sh
```

公开 starter 应稳定退出 1；真实 Grid overlay、track list、DOM/Tab 和截图差分不会由离线 oracle 代替。
