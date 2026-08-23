# 实验：工单创建失败边界

实验用稳定 `Outcome` 报告成功、输入、冲突和系统失败；checked 冲突强制边界决策，未知 gateway 异常被转换并保留 cause。最小资源替身验证关闭顺序和 suppressed，不引入具体 I/O。

~~~bash
cd labs/encyclopedia/ch.java-oop.exceptions-failure-contracts
./verify.sh
~~~

运行前预测 20 条断言。验证器另外重放空 catch、丢 cause、输入误分类、宽捕获误收程序 bug、suppressed 丢失和未处理 checked 编译失败。成功末行是 `LAB PASS`。
