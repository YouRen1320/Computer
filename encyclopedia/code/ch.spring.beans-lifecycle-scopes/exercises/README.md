# singleton 获取 prototype：作用域边界练习
+
## 同一验证入口的状态合同

只修改 README 指定的 `src/main` 可编辑 starter，测试、POM 与验证器保持不变，然后每次都运行 `./verify.sh`。

- `0` + `EXERCISE_GREEN`：登记的测试数量全部通过，状态为 `completed`；
- `41` + `EXPECTED_RED`：测试数量、唯一失败数和本章 sentinel 精确匹配公开 starter；
- `43`：编译、依赖、测试数量、失败形状或工具环境不在上述两种已知状态，必须先读日志诊断。

离线绿灯只覆盖本练习登记的合同；涉及 PostgreSQL/Testcontainers 的章节仍需正文或 lab 明示的真实环境证据。

`PrototypeTicket` 已声明为 prototype；直接向容器查询两次会得到两个对象。但 singleton `TicketIssuer` 在容器启动时只接收并保存了一个 prototype，所以连续 `issue()` 会返回同一对象。

先运行 `./verify.sh`。初始代码应稳定输出 `state=expected-red`，哨兵为 `EXPECTED_FRESH_PROTOTYPE`。只修改 `src/main` 下的 `PrototypeTicketExercise.java`，不要改测试、POM 或验证器。

完成标准：

- `TicketIssuer` 仍是每容器一个 singleton；
- `PrototypeTicket` 仍是 prototype；
- `TicketIssuer` 保存 `ObjectProvider<PrototypeTicket>`，每次 `issue()` 调用 `getObject()`；
- 连续两次 `issue()` 返回不同对象；
- `./verify.sh` 转为 `state=completed`。

关键规则：singleton 注入 prototype 时，注入只发生一次；“prototype”不等于“每次调用自动创建”。需要逐次实例时，必须在调用边界执行查找。

验证器固定使用 JDK 25、Maven 3.9.16、Spring Framework 7.0.8，并以离线模式执行。
