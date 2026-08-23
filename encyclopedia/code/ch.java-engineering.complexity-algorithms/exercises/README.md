# 独立练习：消除平方去重与重复排序，建立可复用索引

关闭 AI，限时 45 分钟。starter 的业务结果部分正确，但嵌套去重操作数过高、每次查询重复排序、Map 索引为空；第一条操作次数 oracle 必须失败。`STARTER EXPECTED FAILURE` 不是完成。

要求：

1. 用保首次 encounter order 的 Set 去重，执行一次 membership add/输入项，同时保留原始 audit List；
2. 三次查询只构建并排序一次快照，结果与逐次排序完全一致；
3. 建立 Map<String,Event>，重复 ID 采用明确“最新事件覆盖”策略；
4. 返回结果不可修改，输入列表保持不变；
5. 缺失键同时验证 containsKey=false 与 get=null；
6. 禁止用墙钟阈值、睡眠或随机输入作为 oracle；
7. 未排序二分故障仍应产生 `UNSORTED_PRECONDITION`；
8. 最终输出 `exercise.assertions=15 passed` 和 `EXERCISE PASS`。

```bash
cd exercises/encyclopedia/ch.java-engineering.complexity-algorithms
./verify.sh
```

变更题：重复策略改为“拒绝并保存全部冲突行”。不能只保留 Map；设计 `List<Event>` 原始事实、Map 索引和冲突报告的更新顺序与失败回滚。
