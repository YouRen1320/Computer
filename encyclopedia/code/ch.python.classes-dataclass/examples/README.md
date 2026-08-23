# 对象模型、dataclass 与 enum 示例

示例用 frozen 值对象表达 AI 优先级建议，用 enum 表达建议审核状态，用普通服务类组合策略，并用 `default_factory` 证明审查队列不共享 list。

```bash
./verify.sh
```

验证同时运行锁定的 mypy 2.3.0：正例必须 strict-green，负例必须产生指定的
`assignment` 与 `arg-type` 诊断；随后再验证 Python 运行时对象合同。它没有验证 Java API
或持久化映射。
