# 练习：修复不安全的配置文件更新器

`src/NioSafetyChallenge.java` 是可编译但会失败的起点。不要改变验证器的故障证据；依次修复下面四类契约：

1. 以显式 UTF-8 解码，并让畸形输入成为可观察失败；
2. 在目标同目录完整写入临时文件，成功后请求原子替换，失败时删除临时文件并保留旧目标；
3. 只相对调用方传入的配置根解析，拒绝绝对路径和规范化后逃逸；
4. 遍历时限制深度、不跟随符号链接，并稳定排序结果。

~~~bash
cd exercises/encyclopedia/ch.java-engineering.nio-files-charsets
./verify.sh
~~~

起点应以 `EXERCISE CHECK PASS mode=starter` 结束，因为验证器确认了首个预期失败。你的完成标准是：同一个脚本输出 `COMPLETED CHALLENGE PASS assertions=12`；成功 oracle 会检查非法 UTF-8、失败/成功后的临时残留、完整替换、绝对与 `..` 拒绝、深度 2、稳定顺序和链接过滤。只修一半会落入其他退出码并失败。不要把 `ATOMIC_MOVE` 不支持时的静默非原子回退当作修复。
