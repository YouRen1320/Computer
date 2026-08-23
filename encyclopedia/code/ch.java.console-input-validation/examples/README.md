# 控制台输入契约示例

`src/WorkOrderAmountCli.java` 展示同一条命令的两种输入入口：恰好两个命令行参数，或标准输入中的一行两个字段。程序只在成功时向 stdout 输出金额；缺参数、EOF、非法数字与越界值只写 stderr，并返回稳定的非零退出码。

运行固定验证：

```bash
bash verify.sh
```

脚本覆盖 args、stdin、零数量、缺参数、非法数字、越界值和 EOF。它验证 stdout、stderr 与退出码三个通道，而不是只看屏幕上“像是正确”。需要 JDK 25。
