# 实验记录单

| 故障 | 失败层 | 第一证据 | 修复 |
|---|---|---|---|
| Mock 形状漂移 | 适配器合同 | mock/host responseShape 不同 | 使用真实脱敏 fixture |
| map 错配 | 符号化 | buildId 与 mapBuildId 不同 | 绑定不可变构建 id |
| 模拟器冒充真机 | 验收声明 | carrier=devtools | 补真实设备或降级声明 |
