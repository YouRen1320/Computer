# 练习：修复工单创建失败契约

起始代码可以编译，但大 try/catch 把输入错误包装成系统错误，未知 gateway 转换又丢失 cause。请保留 checked 冲突签名，缩小捕获范围并让边界得到稳定分类。

要求：

1. 空标题输出 `INVALID_INPUT`，且 gateway 不被调用；
2. 重复请求继续作为 checked `DuplicateWorkOrderException` 交给调用者决定；
3. 未知 gateway 失败转换为 `CreationException` 时保留 cause；
4. 不用 null、空 catch、解析 message 或 `catch(Throwable)` 伪造成功；
5. 成功路径只调用 gateway 一次。

~~~bash
cd exercises/encyclopedia/ch.java-oop.exceptions-failure-contracts
./verify.sh
~~~

未修复时应看到 `STARTER EXPECTED FAILURE status=8`。按第一条 expected/actual 修复后再处理 cause，不要删除故障断言。
