# 实验：同一服务替换两个实现

MemoryRepository 与 JsonLikeRepository 没有继承 Protocol，却都提供 `get/save`。共享合同套件分别运行两者，证明应用服务只依赖端口。

```bash
./verify.sh
```
