# 实验：训练型 CRUD、错误矩阵与依赖清理

该实验实现完整的内存 CRUD 教学切片，覆盖成功、Body 边界、404、409、依赖替换、内部异常安全信封和 204。它不会连接 FactoryCare core schema。

```bash
./verify.sh
```

等价 curl 合同（本实验未启动真实端口）：

```bash
curl -i -X POST http://127.0.0.1:8000/training/work-orders \
  -H 'Content-Type: application/json' \
  -d '{"id":"WO-010","title":"Inspect motor","priority":4}'
curl -i http://127.0.0.1:8000/training/work-orders/WO-010
```

进程内 TestClient 已验证报文合同；上述监听端口/curl 路径明确未执行。
