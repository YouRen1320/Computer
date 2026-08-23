# ch.js.testing-debugging 可运行示例

示例用 Vitest 验证工单摘要纯函数的正常、空输入、非法输入、输入不变，以及异步 loader 成功/失败边界。`vi.fn` 只替换显式数据端口，不模拟纯函数内部算法。

运行 `./verify.sh`。verifier 使用 lockfile 安装、`vitest run` 一次退出，并检查 7 个测试均执行；不会进入 watch，也不会访问真实网络或数据库。
