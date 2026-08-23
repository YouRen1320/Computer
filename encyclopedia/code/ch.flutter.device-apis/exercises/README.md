# 公开练习：设备权限结果映射

编辑 `starter.dart` 的 `mapFailure`，把平台失败转换成稳定的 UI 合同：

- `denied`：允许稍后再次请求；
- `deniedForever`：引导用户打开系统设置，不能伪装成普通拒绝；
- 未知 code：显示通用失败；
- UI 文案不得泄漏平台原始 token、私有路径或原始 message；
- 每个分支提供稳定的诊断 code。

初始 `./verify.sh` 返回 `41`，全部修复后返回 `0`，非预期编译或工具失败返回 `43`。
