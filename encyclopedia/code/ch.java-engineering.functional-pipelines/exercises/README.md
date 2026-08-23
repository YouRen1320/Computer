# Stream、Collector 与 Optional 独立练习
+
## 同一验证入口

只修改本目录 `src/` 中的可编辑 starter，并始终运行 `./verify.sh`。完整 starter 的登记故障返回 `41` 与 `EXPECTED_RED`；实现全部合同且保留独立负例后返回 `0` 与 `EXERCISE_GREEN`；编译错误、部分修复、负例被削弱或其他未知状态返回 `43`。

不要修改 `failures/`、测试数据或验证器来制造绿灯；状态 43 会保留当前首个诊断，修正后仍复跑同一命令。

先用普通循环手算空、单项和混合工单，再完成 TODO。不要用 `parallelStream()`、`peek` 写入、无条件 Optional 强取或修改输入列表。

任务：

1. `filter → map → toList` 返回开放工单 ID；
2. `groupingBy` 按首次遇见顺序累计类别 minutes；
3. 求开放工单总 minutes；
4. 以 `OptionalInt` 表达可能缺失的最高 priority；
5. 用 `orElseGet` 让 fallback 只在缺失时执行。

```bash
./verify.sh
```

starter 应以 `PIPELINE_CONTRACT` 失败；额外故障会以 `OPTIONAL_EMPTY_GET` 失败。修复 starter 不等于删除故障夹具。
