# 实验：预测、绿、注入故障、红、恢复、再绿

## 目标

把金额需求转换成执行前确定的 expected，用 AAA 组织每个 case，覆盖正常、零值、边界和非法输入，并证明错误实现确实会被测试拒绝。本实验属于本书 T1：有显式预言、断言和成功/失败用例，但不使用语言单元测试框架。

## 步骤

1. 阅读金额规则，先在 `worksheet.md` 手算八个 expected；禁止先运行程序抄 actual。
2. 在示例目录执行 `ruby run_tests.rb`，记录 stdout、stderr 和退出码。
3. 执行 `ruby run_tests.rb --inject-fault`。这是预期失败：必须出现 2 个 Failure、0 个 Error、exit 1。
4. 再执行正常命令，必须恢复 8/0/0、exit 0。
5. 执行本目录 `ruby run_cycle.rb`，让元验证器检查完整红—绿闭环。
6. 找到首个可信失败行，说明它如何指向“已开始计费块向下取整”的故障。

## 验收

- 每个 expected 在运行前写入 worksheet；
- 正常、零值、1/30/31/1440 边界与两种非法输入均有 case；
- 故障注入后测试确实红，不能把预期失败当作实验失败；
- 恢复后 Tests run=8、Failures=0、Errors=0，exit 0；
- 能区分 assertion failure、unexpected error、测试未运行与构建成功；
- 能标明本实验为 T1，并说明 T2—T4 未验证。

禁止为了“全绿”把 expected 改成错误实现的 actual。若需求真的改变，必须先修改书面规则与独立预言，再修改实现。
