# 对象模型、dataclass 与 enum 示例

示例用 frozen 值对象表达 AI 优先级建议，用 enum 表达建议审核状态，用普通服务类组合策略，并用 `default_factory` 证明审查队列不共享 list。

```bash
./verify.sh
```

验证只覆盖 Python 运行时对象合同；没有安装静态类型检查器，也没有验证 Java API 或持久化映射。
