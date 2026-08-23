# Maven 生命周期故障分层实验

本实验把同一个金额计算器依次置于四种状态：绿色基线、main 源码缺分号、测试源码找不到业务类、断言期望值错误。`verify.sh` 每次都从干净副本开始并使用 Maven 离线模式。

先填写预测表：

| 注入 | 最后到达阶段 | 会不会出现 `Tests run` | 第一处可信位置 |
| --- | --- | --- | --- |
| main 缺分号 |  |  |  |
| test package 不一致 |  |  |  |
| expected 写成 5998 |  |  |  |

然后运行 `bash verify.sh`，从 `build/*.log` 核对。末尾的 `BUILD FAILURE` 只说明整次构建失败，不能替代前面的阶段、文件位置与 expected/actual。
