# 可中断动效与减少动效矩阵示例

本示例把 open/closed、一次状态进入、快速反向、焦点和 `prefers-reduced-motion` 写成静态合同。`oracle.rb` 检查源码与矩阵，不启动浏览器，也不声称验证实际 compositor、layer、帧率或辅助技术。

```sh
./verify.sh
```

预期退出码为 `0`。真实 Performance trace、动画事件、键盘焦点和屏幕阅读器仍需另行取证。
