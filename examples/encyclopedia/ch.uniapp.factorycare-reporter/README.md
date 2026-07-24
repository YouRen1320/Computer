# FactoryCare 报修聚合流示例

运行 `./verify.sh`，验证设备码解析、附件就绪、稳定幂等键、离线重放、状态映射和版本证据的离线合同。

该示例不启动 uni-app、不连接 FactoryCare API/数据库/对象存储，也不生成可安装小程序；它不能替代真机 E2E。

`COMPLETED` 只是一项 UI 展示分组，显式映射 FactoryCare canonical `VERIFIED` 与 `CLOSED`；它不是 `WorkOrderStatus`，不得进入 API、数据库或客户端回写。
