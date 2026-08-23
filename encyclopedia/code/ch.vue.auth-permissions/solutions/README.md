# 私有参考解：认证与权限边界

参考解从 unknown 启动、校验站内 return URL、区分 401/403，并让假服务端只信自己的 subject/resource policy。检查器与公开练习使用同一四场景合同。

```sh
./verify.sh
```

预期退出码为 `0`；假服务端仍不是生产 RBAC 或安全测试。
