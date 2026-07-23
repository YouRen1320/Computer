# 静态类型与运行时对照

验证器完成两件彼此独立的事：

1. 用 uv 固定运行 mypy 2.3.0，严格检查 `typed_counts.py`；
2. 用 CPython 运行 `runtime_contrast.py`，证明参数标注不会自动拒绝字符串。

```bash
./verify.sh
```

首次运行可能需要 uv 从已配置的软件源下载固定版本；之后可复用缓存。检查器绿色不代表外部 JSON 已通过 Schema 或业务授权。
