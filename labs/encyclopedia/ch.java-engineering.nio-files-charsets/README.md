# 实验：把文件更新做成可验证事务

本实验只使用 `Files.createTempDirectory` 创建的沙箱。先预测“临时写入失败后旧目标、临时文件和符号链接遍历分别会怎样”，再运行验证器对照证据。

~~~bash
cd labs/encyclopedia/ch.java-engineering.nio-files-charsets
./verify.sh
~~~

实验覆盖显式 UTF-8 严格解码、相对路径约束、同目录临时文件、原子替换、失败清理、深度受限遍历与不跟随符号链接。五个故障程序分别重放隐式字符集、直接覆盖、相对基准漂移、跟随链接逃逸和临时文件残留。

完成后请用自己的话回答：原子移动保证了什么、没有保证什么？为什么 `normalize()` 不能替代 `toRealPath()` 的链接边界检查？
