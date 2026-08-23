# 示例：先固定金额预言，再证明测试会红

本示例使用 Ruby 标准库写一个极小测试运行器，不依赖任何语言测试框架。规则是：人工费按“已开始的 30 分钟块”计费，金额全部使用整数分；输入有明确范围。

正常运行：

```bash
ruby run_tests.rb
```

预期为 `Tests run: 8, Failures: 0, Errors: 0`，退出码 0。

故障注入：

```bash
ruby run_tests.rb --inject-fault
```

故障实现错误地向下取整，应得到两个边界 Failure、零 Error 和退出码 1。然后重新运行正常命令，确认恢复为绿。

一键验证完整红—绿闭环：

```bash
ruby verify.rb
```

`test_cases.rb` 中的 expected 是执行前写死的手算结果，不调用被测实现。Ruby 只是演示载体；AAA、预言、断言、正例/边界/非法输入和首个可信失败证据适用于其他语言。
