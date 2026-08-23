# 私有参考解：提交后发布

参考解在当前 Spring 事务上注册 `afterCommit` callback；成功提交后发布一次，回滚时不发布。`./verify.sh` 固定验证 2 个测试全绿。生产系统若需要跨进程最终投递，仍应采用同事务 outbox；内存 callback 不保证进程崩溃后的投递。
