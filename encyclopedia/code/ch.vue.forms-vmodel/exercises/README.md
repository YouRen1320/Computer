# 练习：修复数字输入的模型合同（预期红灯）

起始组件把 `type="number"` 直接绑定给 `symptomDurationMinutes`，但遗漏了明确的数字转换合同。运行：

```sh
./verify.sh
```

当前应以非零退出，并指出模型得到字符串。只修改 `src/DurationField.vue`：让输入 `"30"` 在 Vue 模型中成为数字，同时保留空输入边界；不要改检查器、不要把症状持续时间加入 `CreateReportRequest`。修复后用同一命令转绿，并保存红灯与绿灯输出。

