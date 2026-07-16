# JSON 映射独立练习

`JsonSupport` 已提供受限扁平 parser、边界 record 与文件工具；`WorkOrderJsonMapper.fromJson/toJson` 保留 TODO。不要扩大 parser 范围，也不要引入网络依赖。

任务：

1. 检查六个已知字段和 unknown policy；
2. 转换 schemaVersion、enum、Instant 与 BigDecimal；
3. 保留 assignee missing/null/value；
4. 输出 canonical 白名单 JSON；
5. 证明 UTF-8 文件语义往返；
6. 保留独立错误字符集反例。

```bash
./verify.sh
```

starter 应以 `JSON_MAPPING_CONTRACT` 失败。修复后仍必须让 `WRONG_CHARSET` 夹具失败。
