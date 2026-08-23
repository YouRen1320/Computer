# 练习：修复 UTF-8 复制所有权

起始代码可以编译，但会吞 IOException 并在成功/失败后都留下未关闭流。请让拥有型复制使用 try-with-resources、保留 cause，并继续用实际 read count 写出。

约束：普通与空文本正确；读取失败不能伪装为空；输入和输出在所有拥有型路径关闭；关闭失败保留为 suppressed；不改成一次性整读。

~~~bash
cd exercises/encyclopedia/ch.java-engineering.io-resource-lifecycle
./verify.sh
~~~

未修复时应看到 `STARTER EXPECTED FAILURE status=8`。先修吞错，再让普通/空输入、关闭、cause 与 suppressed 断言暴露。全部完成后仍运行同一个脚本，它会改为接受 `COMPLETED CHALLENGE PASS assertions=16`；任何只修了一半而落入其他退出码的版本都会失败。
