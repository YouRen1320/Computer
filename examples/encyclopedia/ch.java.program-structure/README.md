# `ch.java.program-structure` 可运行正例

本目录保存本章正文所引用的真实源码。示例只依赖 JDK 25，不需要 Maven 或第三方库。

从仓库根目录执行：

```bash
bash examples/encyclopedia/ch.java.program-structure/verify.sh
```

验证脚本会在临时目录中：

1. 使用 `javac --release 25 -encoding UTF-8 -d ...` 编译源码；
2. 检查 `ProgramStructureDemo.class` 是否出现在与 package 对应的目录；
3. 使用类的完整名称启动程序；
4. 把实际标准输出与 `expected-output.txt` 做逐字节比较；
5. 退出时删除临时目录，不污染仓库。

成功预言是退出码 `0`，并显示：

```text
PASS: source compiled, package path exists, and output matches.
```

若本机的 `javac` 不是 JDK 25，`--release 25` 会使验证失败。先回到工具链前置章核对 `javac -version`、`java -version` 和 `JAVA_HOME`，不要通过删除 `--release 25` 掩盖版本问题。
