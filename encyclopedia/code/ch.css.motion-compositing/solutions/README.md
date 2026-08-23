# 私有参考解：动效练习

参考解用 transform/opacity 表达有限过渡，状态徽标只运行一次，焦点 outline 不参与动画，并在 reduce 模式显式取消非必要运动。验证复用公开 oracle。

```sh
./verify.sh
```

退出码应为 `0`。此结果不替代真实 Performance、layer、键盘或屏幕阅读器证据。
