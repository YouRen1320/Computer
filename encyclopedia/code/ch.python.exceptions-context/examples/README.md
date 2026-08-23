# 异常链与资源清理示例

示例把 `JSONDecodeError` 翻译为仓库异常并保留 `__cause__`，同时用计数 context manager 证明成功/失败都只清理一次。

```bash
./verify.sh
```
