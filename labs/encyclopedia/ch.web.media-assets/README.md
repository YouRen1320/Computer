# 实验：错误候选、缺失替代文本与 MIME 漂移

本目录保存修复后的媒体页、观察矩阵和三类故障记录。先运行基线，再在副本中逐一注入：混用 `w/x` descriptor、删除信息图 alt、让视频 URL 返回 `200 text/html`。每次只改一个变量，保存首个证据，修复后运行同一命令。

```bash
./verify.sh
```

唯一验证器只证明修复后的声明与诊断记录一致；`browser_observations_are_predictions` 保持为 true，防止把 JSON 当真实 DevTools 记录。实际完成还需本地 HTTP server、目标浏览器 `currentSrc`/Network、字幕和文字稿任务。

视频二进制不提交仓库，必须在真实实验环境以许可 fixture 配置；未配置时只能报告静态声明通过、播放未验证。
