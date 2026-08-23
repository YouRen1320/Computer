# PostgreSQL 类型边界实验

先在 `worksheet.md` 写预测，再执行 `./verify.sh`。`scenarios.json` 同时覆盖五类类型的合法值、SQL `NULL`、非法值，以及三项诊断注入：高频关系塞入 JSONB、无界集合塞入数组、把需要删除和重排的状态定义成 enum。

oracle 是离线边界模型，不连接 PostgreSQL 18；实验重点是让类型选择、约束需求、故障诊断和可移植性记录能够重复验证。
