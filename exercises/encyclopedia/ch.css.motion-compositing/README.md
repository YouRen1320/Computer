# 独立练习：修复不可中断动效

当前 `styles.css` 故意包含 `transition: all`、width/left keyframes、无限循环、长期 `will-change`、隐藏焦点和缺失 `prefers-reduced-motion`。请只修改 CSS，使 `ruby oracle.rb` 退出 `0`；不得修改 oracle、矩阵或预期输出。

公开 `./verify.sh` 被设计为稳定红灯并退出 `1`，用于证明故障可检测。离线绿灯也不会证明真实合成层、帧率、键盘或屏幕阅读器结果。
