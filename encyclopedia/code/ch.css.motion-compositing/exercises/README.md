# 独立练习：修复不可中断动效

当前 `styles.css` 故意包含 `transition: all`、width/left keyframes、无限循环、长期 `will-change`、隐藏焦点和缺失 `prefers-reduced-motion`。请只修改 CSS，使 `ruby oracle.rb` 退出 `0`；不得修改 oracle、矩阵或预期输出。

公开 starter 由 `./verify.sh` 稳定返回 41；修复完成后仍运行同一命令，正确答案返回 0 并输出 `EXERCISE_GREEN`。部分修改、未知失败或基础设施异常返回 43。离线绿灯也不会证明真实合成层、帧率、键盘或屏幕阅读器结果。
