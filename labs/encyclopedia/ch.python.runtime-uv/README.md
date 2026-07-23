# 实验：识别项目环境与锁定输入

验证器检查 `pyproject.toml`、`.python-version` 和一份最小锁定证据合同，并实际打印当前解释器。仓库资产不联网调用 `uv sync`，因此 `uv.lock` 的真实解析/冷缓存重建仍需学习者在实验副本执行。

```bash
./verify.sh
```
