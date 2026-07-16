# 私有参考答案

`answer.json` 补全公开练习的可观测闭环契约。`verify.sh` 直接调用公开目录的同一个 `verify.rb`，再与 `expected.out` 比较；私有答案不能靠修改 oracle 获得绿灯。

运行：

```bash
./verify.sh
```

这只是字段/计算/规则契约的参考答案，不是生产 SLO 审批，也不证明真实 Spring Boot、Collector、Prometheus、日志/trace 后端、探针或 Pager 通知。
