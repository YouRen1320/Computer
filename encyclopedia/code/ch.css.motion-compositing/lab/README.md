# 实验：布局动画、减少动效与焦点故障

`faults.json` 保存四个注入点及首个可信证据；`styles.css` 是修复后合同。目标是证明同一离线 oracle 能检测并约束 layout-affecting 动画、缺失 reduce、隐藏焦点和结束事件耦合。

```sh
./verify.sh
```

预期退出码为 `0`。Performance trace、layer、事件序列、键盘和屏幕阅读器字段保持 `false`，因为实验没有运行真实浏览器。
