# 练习：删除重复的开放工单计数（预期红灯）

起始模型把 `openCount` 初始化为另一个 `ref`，添加工单时只修改 `orders`，因此两个来源漂移。

```sh
./verify.sh
```

当前命令应非零退出，并显示 `orders=3`、`openCount=1` 的第一分叉。只修改 `src/stats-model.ts`：让开放数成为从当前 `orders` 读取的只读 `computed`；不要在 `addOrder` 中手工同步计数，也不要改检查器。用同一命令取得绿灯并保存前后输出。

