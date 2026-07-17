# 组件合同观察例

示例把 FactoryCare 工单板拆为受控筛选栏、只读工单卡片、受控状态编辑器和父级 Board。测试比较 Props、精确 emit payload、组件 `v-model`、fallback/named/scoped slots 以及父状态更新后的新 Prop。

```sh
./verify.sh
```

本地组件状态更新不代表服务器状态迁移成功；权限、乐观锁、API 错误、真实浏览器焦点/读屏和视觉布局仍需另测。

