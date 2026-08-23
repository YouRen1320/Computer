# 公开练习：修复媒体声明与证据边界

starter 故意包含：picture source 用错属性、srcset 混用 descriptor、信息图缺 alt、装饰图 alt 非空、video 无 controls、MIME 声明错误、字幕/外部文字稿缺失，以及多项越权结论。

```bash
./verify.sh
```

公开 starter 必须由 `./verify.sh` 稳定返回 41。请修改 `answer.html` 与 `answer.json`，并补充同目录 `captions.vtt`、`transcript.html`；不要修改 oracle/expected-red，也不要查看私有解。正确答案由同一命令返回 0 并输出 `EXERCISE_GREEN`，部分修改、未知失败或基础设施异常返回 43。

绿灯仍只证明静态合同。真实 `currentSrc`、HTTP/MIME、codec、字幕 UI 与辅助技术必须在获批浏览器/服务器环境另验。
