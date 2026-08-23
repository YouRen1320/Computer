# 实验记录单

| 故障 | 首个证据 | 修复后判据 |
|---|---|---|
| 分包环 | package dependency graph | 无环且路由回归绿 |
| 陈旧缓存 | schemaVersion/decoder | 失效回源或迁移 |
| 过度预载 | beforeInteractive bytes + 候选样本 | 预载为 0 且 P50/P95 在预算 |
