# 练习：修复工单创建失败契约
+
## 同一验证入口

只编辑本目录 `src/` 中的 starter，并始终运行 `./verify.sh`：完整 starter 精确返回 `41` 与 `EXPECTED_RED`；全部合同及独立故障夹具通过时返回 `0` 与 `EXERCISE_GREEN`；编译失败、只修了一部分、故障夹具被削弱或其他未知状态返回 `43` 并保留首个诊断。

因此修正后无需改跑私有脚本，也不要修改 `failures/`、验证器或退出码来制造绿灯。

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
