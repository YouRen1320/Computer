# 公开独立练习：补齐跨端证据

`answer.json` 故意只构建/运行 H5，并把不支持结果留空。请修复为：

- 构建 `h5` 和 `mp-weixin`；
- H5 只含 `h5-adapter`，微信只含 `weixin-adapter`；
- 两目标都命中支持与不支持分支；
- H5 分享和微信文件能力都有明确 fallback。

先运行 `./verify.sh` 保存红灯，再修改并用同一命令重跑。不要查看私有解答。
