# 实验：同一服务替换两个实现

`MemoryRepository` 与真实的 `JsonFileRepository` 没有继承 Protocol，却都提供 `get/save`。
文件实现把 UTF-8 JSON 写入系统临时目录并用同目录临时文件加 `os.replace` 更新；验证器用
锁定的 mypy 检查两个结构实现，再由共享合同运行两者，并重新创建文件仓库证明数据确实来自磁盘。

```bash
./verify.sh
```
