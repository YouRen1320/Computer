# Lab：筛选副作用生命周期轨迹

实验组件记录 `start → cleanup/abort → commit → updated → unmounted`，并暴露活动资源计数。`faults/MissingCleanupPanel.vue` 会让旧 ALL 请求在 CREATED 结果之后覆盖 DOM；`faults/WrongWatchSource.vue` 把普通字符串交给 watch，来源改变时不重跑。

```sh
./verify.sh
```

先保存负例的第一分叉，再观察正常组件。计时器和 Happy DOM 提供确定顺序，不代表真实 fetch、服务器取消、后台标签页节流、SSR 或辅助技术行为。
