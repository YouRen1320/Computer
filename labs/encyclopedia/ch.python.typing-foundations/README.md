# 实验：正负类型 fixture 与收窄

`positive.py` 使用 `object`、`isinstance` 和 `is None` 建立安全收窄；`negative.py` 故意包含错误容器元素、未处理 None 和错误返回。

验证器要求正例退出 0、负例退出非 0，并检查三类预期错误码。这样能排除“mypy 根本没运行也算预期失败”的假证据。

```bash
./verify.sh
```
