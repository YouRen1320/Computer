# 私有解析：fake 与 spy

解析只完成两处职责：fake 把工单按 ID 保存到实例级 map；spy 把“接收者|消息”追加到实例级 list。它没有引入 static、sleep、真实 I/O 或额外调用顺序。

核对时重点解释：

- 为什么 fake 的绿灯不证明数据库唯一约束；
- 为什么 spy 适合事后状态断言；
- 为什么 Mockito 只验证通知边界，不 mock `WorkOrder` record；
- 为什么每个测试都新建 fixture。

```bash
./verify.sh
```
