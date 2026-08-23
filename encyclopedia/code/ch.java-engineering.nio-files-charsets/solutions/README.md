# 私有参考实现：安全文件读取与替换

该参考实现给出一条完整证据链：显式 UTF-8 严格解码、调用方提供的路径基准、同目录临时文件、失败清理、原子替换请求、受限且稳定的目录遍历，以及词法路径与真实路径在符号链接处的差异。

~~~bash
cd solutions-private/encyclopedia/ch.java-engineering.nio-files-charsets
./verify.sh
~~~

验证器在 Java 25 下运行正常路径，并单独重放五类确定性故障。所有文件都写入系统临时目录，验证结束后清理。
