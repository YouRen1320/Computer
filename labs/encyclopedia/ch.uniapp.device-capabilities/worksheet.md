# 实验记录单

| 故障 | 首个可信证据 | 健康判据 |
|---|---|---|
| 拒绝当空数据 | 设备结果联合 | `denied` 保持独立，不产生位置 payload |
| 重复请求权限 | 权限端口调用计数 | 拒绝后页面显示只 check，request 总数为 1 |
| 部分提交误报成功 | attachment 与 work-order 两阶段结果 | 保留 attachment/idempotency，状态为 commit-failed |

记录注入前提、运行命令、红灯、最小修复、同命令绿灯和真机残余风险。
