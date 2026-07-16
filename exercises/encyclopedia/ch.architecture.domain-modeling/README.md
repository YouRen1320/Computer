# 练习：移除通用状态 setter

starter 的 triage/assign 命令正确，但公开 `setStatus` 仍可绕过全部规则。先运行 `./verify.sh`，确认只有 `EXPECTED_NO_PUBLIC_STATUS_SETTER` 红灯；再移除通用写入口，保留有业务含义的命令。

验证器接受未经修改的确定性红灯或完成后的全绿；不要改反射断言或给 setter 增加任意目标状态分支。
