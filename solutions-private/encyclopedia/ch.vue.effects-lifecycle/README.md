# 私有解析：每次 watcher 运行拥有自己的 cleanup

解析只在回调参数中接收 `onCleanup`，并同步注册本次 controller 的 abort；没有改请求键或检查器。

```sh
./verify.sh
```

这个静态 oracle 不证明真实服务器取消或陈旧结果提交防线；完整实验还使用 run ID 和受控计时器验证这些边界。

