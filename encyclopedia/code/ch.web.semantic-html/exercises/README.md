# 公开练习：修复语义化工单页

`answer.html` 是故意损坏的 starter：视觉分组全部使用通用容器，标题跳级，根语言和关键元数据缺失，还试图用 `role` 粉饰结构。请不要查看私有解；先运行唯一验证器观察稳定红灯，再根据内容职责修复。

```bash
./verify.sh
```

公开 starter 必须由 `./verify.sh` 稳定返回 41。完成练习时仍运行同一命令：正确答案返回 0 并输出 `EXERCISE_GREEN`，部分修改、未知失败或基础设施异常返回 43。不要修改 oracle 或 `expected-red.out`；需要补齐四类意图注释、原生区域、显式标题序列和文本语义，同时保持无 CSS、表单和脚本边界。

离线 oracle 是课程子集检查，不证明 WHATWG 完整合规或真实辅助技术可用。另行保存 HTML checker、DOM/Accessibility 和读屏器任务证据。
