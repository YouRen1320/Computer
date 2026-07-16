# ch.java.platform-toolchain 可运行示例

本示例显式展示 `源码 → class → JVM 进程`，目标版本是 JDK 25。

## 前置检查

```zsh
java -version
javac -version
```

两者的 feature version 都应为 25。随后在本目录执行：

```zsh
bash scripts/verify.sh
```

脚本只清理本目录的 `build/`，并依次验证：

1. `javac --release 25` 编译成功；
2. 生成 class 的 major version 为 69；
3. JVM 输出精确等于 `FactoryCare toolchain OK`；
4. 正常运行退出码为 0；
5. `--release 99` 在 compile 阶段返回非 0；
6. 空 classpath 在 JVM 加载阶段返回非 0；
7. 报告写入 `build/verification-report.txt`。

`build/` 是生成物，已由仓库规则忽略。不要把本机绝对路径硬编码进源码。
