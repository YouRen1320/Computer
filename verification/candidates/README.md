# Bootstrap candidates

本目录只描述候选生成规则，不存放可执行最终合同。运行：

```bash
ruby scripts/generate-verification-manifests.rb --coverage --json
ruby scripts/generate-verification-manifests.rb --bootstrap-candidates --json
```

覆盖审计会把 canonical catalog 的 255 章与 `verification/manifests/` 比较。候选生成会为每个缺口逐章记录 examples、labs、exercises 中唯一 `verify.sh` 的相对路径、摘要、模式、shebang、静态工具提示与建议退出码，并显式列出六项待复核工作。

候选状态固定为 `bootstrap-observed-unreviewed`。它没有扩展传递输入、没有探测精确工具版本、没有执行命令、没有锁定输出集合，也没有人工确认预言机，因此不能移动到 `verification/manifests/`，不能作为章节 `review/verified` 或用户学习完成证据。
