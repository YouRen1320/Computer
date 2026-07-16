# 修复连接未归还

starter 在成功查询后仍把连接留在 active 状态。只能修改 `ConnectionBorrower`，用明确资源所有权修复；不要放宽测试、增大池或吞掉异常。

运行 `./verify.sh` 应稳定得到一个 `EXPECTED_CONNECTION_RETURNED` 红灯。完成后同一入口会识别全绿；私有答案只用于课程验证。
