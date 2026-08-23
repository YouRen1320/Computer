# 层叠误判故障实验

目标：从同一语义页面的候选声明中诊断 priority、inheritance 与 source-order 三种误判。`faults.json` 保留注入、首个证据、修复、原验证重跑和残余风险；`observation-matrix.json` 保存离线预言，并明确真实浏览器观察尚未完成。

```bash
./verify.sh
```

绿灯只确认修复夹具和故障记录自洽。正式实验需在目标浏览器中打开 `index.html`，逐项截图/导出 Styles 与 Computed，先写禁用胜者后的预测，再执行禁用操作。
