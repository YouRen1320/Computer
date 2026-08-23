# 隔离解析：ch.java.platform-toolchain

只有在完成公开练习并保存自己的预测后再阅读。

## A 组要点

1. 输出路径是 `out/com/example/App.class`；`-d out` 是输出根，package 映射为子目录。
2. `out` 是搜索根，JVM 会在其下拼出 `com/example/App.class`。
3. 不会。`javac` 只完成编译；只有启动 JVM 并执行到输出语句才会出现程序输出。
4. 通常仍是 JDK 25，因为 shell 直接按继承的 `PATH` 查 `java`。必须结合 `type -a java`、`command -v java` 和实际 `java -version`，不能只看 `JAVA_HOME`。

## B 组分类

- `command not found`：shell 解析/启动前；先查拼写和 `type -a javac`。
- `release version 99 not supported`：compile；先查 `javac -version` 与 `--release`。
- `Could not find or load main class`：JVM 加载；先查 classpath 根、完整类名和 class 实际路径。
- `IllegalStateException` 且栈指向 `App.main`：程序已运行；先读异常类型、消息和首个业务栈帧。

## 可复现命令骨架

```zsh
mkdir -p out/classes
javac --release 25 -d out/classes src/com/example/App.java
javap -classpath out/classes -verbose com.example.App | grep 'major version'
java -cp out/classes com.example.App
```

需求变更题应先把精确预期改为两行，再运行程序并比较完整标准输出；只看到退出码 0 不足以证明新文本正确。
