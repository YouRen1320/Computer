# 私有参考解：独立公共响应模型

参考解使用 `OrderResponse` 作为 response model。运行时返回值即使含内部字段，也会只输出公共合同；验证器同时检查 JSON 和 OpenAPI `$ref`。
