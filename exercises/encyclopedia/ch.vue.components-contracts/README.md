# 练习：把嵌套 Prop mutation 改为事件合同（预期红灯）

起始状态编辑器直接写 `props.order.status`。父对象会变化，却没有任何事件说明是谁、为何改变。

```sh
./verify.sh
```

当前应非零退出。只修改 `src/StatusEditor.vue`：禁止修改 Prop，声明并发出 `request-status-change`，payload 精确包含 `orderId` 与 `nextStatus`；不要改检查器或复制整个 order。修复后用同一命令转绿并保存红—绿输出。

