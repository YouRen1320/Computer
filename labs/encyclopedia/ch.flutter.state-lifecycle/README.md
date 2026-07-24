# 实验：latest-wins 状态机

`operations.yml` 包含两个独立证据：

- 故意让后发请求 B 先完成，再让 A 完成，验证 `currentOperation == operation && mounted` 的提交规则，确认旧 A 不覆盖 B；
- 把工单列表从 `[WO-A, WO-B]` 重排为 `[WO-B, WO-A]`，按业务 `Key` 恢复局部状态，确认 `expanded/collapsed` 状态跟随工单身份而不是列表位置。

```bash
./verify.sh
```

这是确定性状态机夹具，不声称运行了真实 Flutter Widget 树或网络请求。
