# JSON 映射独立练习
+
## 同一验证入口

只修改本目录 `src/` 中的可编辑 starter，并始终运行 `./verify.sh`。完整 starter 的登记故障返回 `41` 与 `EXPECTED_RED`；实现全部合同且保留独立负例后返回 `0` 与 `EXERCISE_GREEN`；编译错误、部分修复、负例被削弱或其他未知状态返回 `43`。

不要修改 `failures/`、测试数据或验证器来制造绿灯；状态 43 会保留当前首个诊断，修正后仍复跑同一命令。

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
