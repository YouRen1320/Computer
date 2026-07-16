# 修复“提交前发消息”

当前 Service 在数据库事务提交前调用 Publisher。成功路径看似正常，但后续异常使数据库回滚时，已经发布的消息无法撤回。运行 `./verify.sh` 会稳定得到 2 个测试中的 1 个失败，哨兵为 `EXPECTED_AFTER_COMMIT_ONLY`。

只修改 `CreateService.create()`：不要直接 publish，而要在当前 Spring transaction synchronization 的 `afterCommit` 回调中发布。目标为成功时提交两类结果，回滚时数据库和 Publisher 都为空。
