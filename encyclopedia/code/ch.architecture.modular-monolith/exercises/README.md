# 模块化单体独立练习

修复八个 `TODO`：internal 隔离、无环、允许边、实体 owner、最小 shared kernel、派生失败隔离、模块独立测试和证据化拆分。

```bash
./verify.sh
```

起始代码固定红灯于 `INTERNAL_PACKAGE_EXPOSED`；不得通过把模块设为 open 或删除结构断言消音。
