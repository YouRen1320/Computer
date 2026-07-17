# ch.js.testing-debugging 公开练习（预期红灯）

运行 `./verify.sh` 应非零退出并包含 `UNTRUSTED_ORACLE_EXERCISE`。受测实现已经满足合同，故障在 expected：

1. 先手算三条输入的总数和状态计数；
2. 修正错误 expected，不能改实现迎合 99；
3. 保留空输入、异常、输入不变和 async rejection 断言；
4. 确认 `expect.assertions` 与 `await rejects` 都实际执行；
5. 不改 verifier、跳过测试或删除断言来制造绿灯。

private solution 只在独立修复后核对。
