# Lab：父子数据流、事件与 Slot 合同

实验拆分筛选栏、卡片、状态编辑器和父级 Board，保存父状态、Props、emitted payload、组件 v-model 与 scoped-slot DOM。`faults/MutatingStatusEditor.vue` 在没有事件时直接修改父对象；`faults/WrongEventEditor.vue` 发出错误事件名，父值保持不变。

```sh
./verify.sh
```

先保存负例的第一可信证据，再与正常父级处理路径比较。本地状态变化不证明 FactoryCare 服务端授权、合法状态机迁移、乐观锁或持久化成功。

