# 修复漏租户查询条件

starter 方法接收 tenantId，却只按工单 ID 查询。只能修复 `@Select`，保留参数绑定；不要删除租户参数、放宽测试或使用字符串替换。

`./verify.sh` 应稳定显示唯一红灯 `EXPECTED_TENANT_PREDICATE`；修复后同一入口全绿。
