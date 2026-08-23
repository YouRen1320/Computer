# 实验：父子环境、PATH 顺序与版本来源

先填写 `worksheet.md`，再运行本实验。不要编辑 `.zshrc`、删除 JDK、改变系统默认或复制完整环境。所有 A/B 工具均由验证器在新临时目录创建。

实验顺序：

1. 预测父、临时子命令和后续父进程看到的 `DEMO_MARKER`；
2. 对普通变量与导出变量分别预测子进程可见性；
3. 预测 A:B 与 B:A 两种 PATH 顺序；
4. 对照 `type -a`、`command -v`、裸命令和绝对入口；
5. 用占位符模拟 PATH 的 Java=A、JAVA_HOME=B、Maven runtime=B；
6. 只在子会话中对齐到 B，证明父会话未被改动；
7. 记录未验证的真实工具与 IDE 边界。

夹具自动检查：

```text
ruby verify.rb
```

预期最后一行是 `environment-tool-resolution lab fixture: PASS`。自动检查不批改 worksheet，也不检查真实机器配置。
