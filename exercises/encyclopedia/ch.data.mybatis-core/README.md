# MyBatis core 独立练习

`answer.json` 是故意错误的 starter。先预测第一条失败规则，再逐项修复 mapper 合同：

- 完整 statement id 与 namespace/id；
- `#{}` 路径、动态 WHERE 和空 ids 语义；
- record 列映射与空/单/多基数；
- 固定排序白名单与 N+1 查询预算；
- 带 statement id 的失败证据和同输入重跑；
- mapper 不拥有 Spring 事务代理。

运行 `./verify.sh` 应得到 `EXPECTED_RED`，这证明 starter 确实不能冒充答案。私有答案不在本目录。
