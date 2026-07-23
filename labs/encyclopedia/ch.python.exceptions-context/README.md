# 实验：失败时保留原文件

`atomic_store.py` 在同目录写临时文件后 `replace`。验证器覆盖成功与序列化失败：失败时目标 digest 不变且临时文件被清理。

```bash
./verify.sh
```

这是本地标准文件系统测试，不外推 NFS、崩溃耐久性或 Windows 占用语义。
