# 响应式图片、字幕视频与失败回退：离线示例

本目录提供一页完整媒体声明：实际可读取的 SVG 图片候选、装饰图、poster、WebVTT 和文字稿，以及故意不提交仓库的教学视频二进制。`manifest.json` 明确区分“离线存在”与“真实 HTTP/codec 待验证”，`observation-matrix.json` 是打开浏览器前的预言。

```bash
./verify.sh
```

唯一验证器只检查 HTML 声明、替代文本、srcset/sizes、video controls/source/track、WebVTT、文字稿和证据诚实性。它不启动浏览器、不发 HTTP、不解码视频，也不声称 `currentSrc` 或字幕 UI 已观察。

要完成真实实验，请为清单中的视频 URL 配置获批本地 fixture server，记录浏览器版本、视口、DPR、格式支持、缓存、Network、`currentSrc`、字幕与文字稿任务。不要把真实 FactoryCare 附件、签名 URL 或个人数据放入本目录。
