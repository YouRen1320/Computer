# ch.js.testing-debugging 私有参考解

参考解只修正独立 expected，不改生产实现迎合测试。它保留正常、空、异常、输入不变与异步拒绝五类证据。运行 `./verify.sh` 应由 Vitest 执行 5 个测试并零退出。
