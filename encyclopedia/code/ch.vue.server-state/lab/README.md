# 实验：旧响应、finally 与卸载后更新

实验保存三类注入故障及修复后的控制器。受控 Promise 会故意忽略 abort，让 request identity 独立承担最后提交门。

```sh
./verify.sh
```

预期退出码为 `0`。真实 Vue watcher、浏览器 Fetch、Network 面板和服务器处理均未运行。
