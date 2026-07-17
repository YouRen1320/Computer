# ch.js.testing-debugging 实验

基线为 7 个 Vitest 单元测试，覆盖正常、边界、异常、所有权和替身边界。`faults/` 分别注入：

- `UNTRUSTED_ORACLE_WRONG_EXPECTED_VALUE`；
- `FALSE_POSITIVE_UNAWAITED_ASYNC_ASSERTION`；
- `TEST_ISOLATION_LEAK_SHARED_FIXTURE`；
- `FALSE_POSITIVE_CAUGHT_ERROR_SILENT`。

运行 `./verify.sh`。通过要求基线 7 测试全部绿，四个故障测试各自非零退出且日志包含稳定标记。这组故障相当于保存“故意改坏后，在目标断言红”的证据。
