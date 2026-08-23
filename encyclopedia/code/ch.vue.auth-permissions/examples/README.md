# 认证、导航、权限 UI 与服务端拒绝示例

本示例以无网络 Node 策略夹具验证 unknown bootstrap、站内 return path、allow/sign-in/forbidden 导航、capability UI、401/403 分类，以及绕过 UI 后仍由假服务端拒绝。

```sh
./verify.sh
```

预期退出码为 `0`。假服务端不是生产 RBAC；真实 Vue Router、Pinia、Cookie/Token、浏览器与后端均未验证。
