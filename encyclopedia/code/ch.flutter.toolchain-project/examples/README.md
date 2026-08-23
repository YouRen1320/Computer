# Flutter 工具链证据示例

这是一个不伪造设备结果的最小示例。`evidence-contract.yml` 定义应采集的环境、目标、构建和 reload/restart 证据；`verify.sh` 只验证合同结构与脱敏规则。

默认验证不调用本机 Flutter，因为仓库校验必须离线、可重复，也不能把某台机器的设备状态冒充所有读者的结果。学习者在自己的练习副本中把 `actual: pending` 替换为真实记录，并按教材运行 Flutter 3.44.x 对应命令。

运行：

```bash
./verify.sh
```

通过表示“证据合同完整”，不表示 Android、iOS、Web 或桌面真机已经通过。
