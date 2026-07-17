# 盒尺寸、包含块与层叠树示例

本例用固定 px 输入同时展示 content-box/border-box、absolute containing block、两个兄弟 stacking contexts 与 hidden/clip 边界。

```bash
./verify.sh
```

绿灯证明手算矩阵和静态结构没有漂移。它不运行浏览器，不能证明真实盒模型、遮挡截图、sticky/scroll 或视觉差分；这些字段在 `geometry-matrix.json` 中明确为 false。
