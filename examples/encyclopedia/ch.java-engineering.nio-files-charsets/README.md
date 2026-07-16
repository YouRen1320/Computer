# 示例：Path、Files 与安全替换观察台

示例只在自建临时目录中运行：显式 UTF-8 严格解码、按明确 base 解析、临时文件失败保护旧目标、原子替换成功清理临时文件，并过滤指向外部目录的符号链接。

~~~bash
cd examples/encyclopedia/ch.java-engineering.nio-files-charsets
./verify.sh
~~~

验证器还会用受控子 JVM 重放默认字符集错误，并真实制造直接覆盖半文件、错误相对基准和符号链接逃逸。成功末行是 `EXAMPLE PASS`。
