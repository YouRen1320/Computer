# 独立练习：设备引用、身份与空路径

关闭 AI，限时 25 分钟。`src/ReferenceChallenge.java` 可以编译和运行，但故意把“状态相同”写成了 `==` 身份比较，并在空引用路径直接访问字段。

先预测原始版本的退出状态与第一条错误证据，然后完成：

1. 保留 `primary`、`alias`、`peer`、`missing` 四个变量；
2. 证明 `primary` 与 `alias` 身份相同；
3. 证明 `peer` 状态相同但身份不同；
4. 经 `alias` 修改后，`primary` 观察到 `RUNNING`，`peer` 仍为 `IDLE`；
5. 把 `missing` 路由为 `REJECT_MISSING_DEVICE`，不能把它当空字符串；
6. 最后打印 `challenge.assertions=8 passed`。

运行固定验证器：

```bash
cd exercises/encyclopedia/ch.java-oop.references-null-identity
./verify.sh
```

初始版本应打印 `STARTER EXPECTED FAILURE`；正确完成后验证器应打印 `EXERCISE PASS`。第一次独立尝试前不要打开私有解析。

变更练习：增加 `backup`，先令它与 `peer` 成为别名，再把 `peer` 重新赋值为 `primary`。不运行代码，画出每一步三个对象关系，再添加断言证明旧对象仍可由 `backup` 访问。
