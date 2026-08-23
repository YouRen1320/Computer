# 公开练习：发布物与监控版本关联

编辑 `release.env`，建立可审计的发布清单。必须提供唯一的键：flavor、application id、
语义版本、递增 build number、40 位 commit、artifact 与 symbols 的 64 位 SHA-256，且
`MONITORING_RELEASE` 必须严格等于：

`factorycare-mobile@<VERSION>+<BUILD_NUMBER>-<FLAVOR>`

本练习只验证清单合同，不声称生成了真实签名、真实制品或真实监控事件。初始
`./verify.sh` 返回 `41`，修复后返回 `0`，文件结构或工具异常返回 `43`。
