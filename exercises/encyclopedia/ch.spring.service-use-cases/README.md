# 修复 CRUD 转发服务

starter 直接把状态字符串交给 Repository，绕过聚合。只能修改 `CrudForwardingService.assign`，恢复 load→domain.assign→save；不要放宽测试或把规则搬进 Repository。

`./verify.sh` 应稳定显示唯一红灯 `EXPECTED_USE_CASE_ORCHESTRATION`；修复后同一入口全绿。
