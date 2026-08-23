# 练习：为筛选请求补上失效清理（预期红灯）

起始组件每次筛选都创建 `AbortController`，却没有把它注册到 watcher cleanup。快速切换时旧运行仍可提交。

```sh
./verify.sh
```

当前应非零退出。只修改 `src/FilterEffects.vue`：通过 watch 回调的 cleanup 合同，在本次运行失效时 abort 本次 controller；保留 signal 传递，不改检查器或用全局 controller。修复后用同一命令转绿并保存红—绿输出。

