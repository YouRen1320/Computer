# singleton 获取 prototype：作用域边界练习

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
