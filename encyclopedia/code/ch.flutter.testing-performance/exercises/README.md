# 公开练习：可终止测试与性能证据合同

编辑 `test-contract.env`，修复四类证据漂移：

1. 无限动画不能依赖 `pumpAndSettle`，应使用受控 future 与精确 pump；
2. golden 必须固定 Flutter runner 与字体 fixture 指纹；
3. 创建的 controller 必须全部 dispose；
4. 性能结论必须要求在代表性设备上用 profile mode 采集。

这里只验证测试计划合同，不声称已经产生真实 golden 或 profile 数据。初始 `./verify.sh`
返回 `41`，修复后返回 `0`，文件结构或工具异常返回 `43`。
