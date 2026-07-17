# 层叠冲突矩阵示例

本例把同一告警卡片的选择器、层、权重和源码顺序写成固定矩阵，并用离线 Ruby oracle 复算。运行：

```bash
./verify.sh
```

绿灯证明 HTML/CSS 意图注释、固定选择器权重、层叠矩阵、继承与删除规则预言没有漂移。它不启动浏览器；`matrix.json` 明确把真实 computed style 与视觉差分标为未验证。正式观察请用本地静态服务器打开 `index.html`，逐项记录浏览器版本、Styles、Computed 和禁用胜者后的结果。
