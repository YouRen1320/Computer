# 公开红灯：修复 Composable 所有权

直接运行 `./verify.sh` 应失败并输出 `EXPECTED_RED`。当前实现把状态放在模块作用域、没有把 AbortSignal 交给 repository，也把可写 ref 暴露给消费者。

任务：让每次调用创建自己的状态；watcher 每轮拥有 AbortController 并在无效化时清理；返回 readonly refs 与显式命令。不得削弱检查器或复制私有解答。修复后同一命令应转绿。

