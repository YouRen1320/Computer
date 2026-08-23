# 审计事实与隐私故障注入实验

本实验用离线内存账本重放七个互相独立的缺陷：接受禁止详情字段、缺租户、缺责任主体、业务回滚却记录成功、覆盖已有事件、跨租户查询，以及把追踪 ID 当作责任主体。

```bash
./verify.sh
```

验证器先比较安全基线，再逐项运行：

- `SECRET_FIELD`
- `MISSING_TENANT`
- `MISSING_ACTOR`
- `FALSE_SUCCESS`
- `MUTABLE_AUDIT`
- `CROSS_TENANT_QUERY`
- `TRACE_AS_ACTOR`

每项必须产生唯一故障标记。实验不证明内存存储具备生产级持久性、防篡改、留存或访问控制；这些边界仍需数据库约束、权限策略和真实集成测试。
