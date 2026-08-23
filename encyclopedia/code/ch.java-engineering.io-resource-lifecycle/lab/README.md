# 实验：UTF-8 文本复制生命周期

实验把底层读取限制为一次一个字节，证明字符桥能跨块恢复 UTF-8；同时验证空输入、字符上限、借用资源、第二资源初始化失败和双 close 异常。

~~~bash
cd labs/encyclopedia/ch.java-engineering.io-resource-lifecycle
./verify.sh
~~~

运行前预测 24 条断言和五个故障退出码。成功末行是 `LAB PASS`。
