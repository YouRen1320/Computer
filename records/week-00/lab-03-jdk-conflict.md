# Lab 3：安全的 JDK 版本冲突模拟

- 日期：2026-07-12
- 约束：不修改系统默认、不删除 JDK、不写入 Shell 配置。

## 现象

在一次性子 Shell 中只把 `JAVA_HOME` 指向 Oracle JDK 21，继承原有 `PATH`：

```bash
env JAVA_HOME="$(/usr/libexec/java_home -v 21)" zsh -c '
echo "JAVA_HOME=$JAVA_HOME"
type -a java mvn
java -version
mvn -v
'
```

实际结果：

- 临时 `JAVA_HOME` 指向 Oracle JDK 21；
- `PATH` 的第一个 `java` 候选仍是 Temurin JDK 25；
- `java -version` 显示 Temurin 25.0.3；
- `mvn -v` 显示 Maven 3.9.16 使用 Oracle Java 21.0.10。

## 假设与结论

- Shell 通过 `PATH` 查找 `java`，仅改变 `JAVA_HOME` 不会自动改写 `PATH`；
- Homebrew Maven 启动脚本主动读取 `JAVA_HOME`，因此与直接执行的 `java` 使用了不同 JDK；
- 只看 `java -version` 会错误地认为整个 Java 工具链已经一致。

## 恢复与复验

一次性子 Shell 结束后，变量修改随子进程销毁，不会反向污染父 Shell。父 Shell 复验结果：

- `JAVA_HOME`：Temurin 25；
- `java -version`：Temurin 25.0.3；
- `mvn -v`：Maven 3.9.16 使用 Temurin 25.0.3。

未修改 `.zprofile`，无需文件回滚。

