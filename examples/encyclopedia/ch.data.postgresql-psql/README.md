# psql 连接与脚本证据最小示例

本机没有 PostgreSQL 客户端或服务器；该示例使用离线 oracle 检查一个**不会被执行**的合成本地连接计划、只读脚本和固定 transcript。

运行：

```sh
./verify.sh
```

它会验证显式 host/port/database/role、连接超时、`-X`、非交互认证、`ON_ERROR_STOP`、脚本路径、会话探针、显式只读事务，以及 psql 0/1/2/3 退出分类。它不会探测端口、读取密码或连接数据库。
