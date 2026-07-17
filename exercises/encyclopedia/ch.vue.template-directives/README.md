# 公开练习：让工单节点跟随业务身份

starter 已能显示 A、B 两张工单卡，但 `:key="index"` 把渲染位置误当成业务身份。验证器先保存 B 的节点对象，再把输入重排为 B、A；starter 会输出确定性身份红灯。

```sh
./verify.sh
```

只修改 `src/WorkOrderList.vue` 的 key 表达式，使用稳定唯一的工单字段。不得删除重排矩阵、改数据 ID、让验证器接受新节点或用随机数。修复后输出 `EXERCISE PASS identity=stable`。
