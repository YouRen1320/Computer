# 私有解析：以精确事件替代 Prop mutation

解析保持 order 为只读输入，状态选择只发 `request-status-change({ orderId, nextStatus })`，由父级决定是否写入。

```sh
./verify.sh
```

该静态 oracle 不证明服务器允许迁移或已经持久化；完整实验只验证本地父子所有权、事件名与 payload。

