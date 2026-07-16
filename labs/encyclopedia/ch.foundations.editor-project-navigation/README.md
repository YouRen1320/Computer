# 实验：从错误候选回到规范源码

本实验要求你用自己的 VS Code 或 IntelliJ IDEA 完成导航，但验证输入是完全离线的固定样例。`workspace/` 是应打开的项目根；`src/` 不是根；`target/generated-sources/` 中的同名文件是故意设置的陷阱。

## 操作顺序

1. 不运行验证器，先在 `worksheet.md` 写出项目根、规范定义、测试引用、生成候选与预期失败；
2. 以 `workspace/` 为打开范围，使用文件搜索找到三个路径角色；
3. 从测试中的 `WorkOrderLabel.label` 调用跳到生产定义，再查找引用并返回；
4. 打开 `problems.txt`，判断诊断生产者、第一处可信文件与为何不能修改生成物；
5. 把结果填入 `navigation-evidence.txt`，不得复制用户名、绝对路径或 IDE 私有缓存；
6. 执行固定验证器并根据精确差异修复。

首次运行：

```text
/usr/bin/ruby --disable-gems verify.rb
```

应以非零退出并提示 `project_root` 仍是 `<fill>`，这是预期失败。填写全部字段后，最后一行应为 `editor navigation lab: PASS`。验证器把 `workspace/` 与证据复制到新临时目录，用固定 Ruby 与 `/bin/zsh -f` 观察，不联网、不加载个人配置、不修改本目录。

自动通过不能证明你执行了 IDE 的定义/引用跳转。还需现场演示一次“测试调用→生产定义→引用列表→返回测试”，并用 120 秒解释为何全文搜索候选不等于语义引用。
