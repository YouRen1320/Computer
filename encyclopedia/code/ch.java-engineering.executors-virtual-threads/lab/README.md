# 实验：FactoryCare 维修查询的结果、超时、取消与关闭

## 目标

用 Executor 提交独立维修查询，区分成功、异常、超时和取消；证明中断只是协作请求；验证执行器关闭后拒绝新任务且无遗留平台 worker；再对比虚拟线程版本，并用受控丢更新反例证明虚拟线程不修复共享状态。

```bash
labs/encyclopedia/ch.java-engineering.executors-virtual-threads/verify.sh
```

实验完全离线，只使用 Java 25 标准库和合成工单。所有协作点由 latch、barrier 或 semaphore 表达；每个等待都有 2 秒故障上限。40 毫秒只用于制造必然未释放 latch 的 `TimeoutException`，不以精确耗时作为通过标准。

## 先预测

1. `Future.get()` 遇到任务异常时，直接抛原异常还是包装为 `ExecutionException`？
2. `cancel(true)` 返回 true 后，吞中断任务是否已经结束？
3. `shutdown()` 是否等待已提交任务结束？何时才可断言 `isTerminated()`？
4. 六个虚拟线程任务为何仍要用只有两个 permit 的 `Semaphore`？
5. 两个虚拟线程同时执行普通 `counter++`，会自动变成原子操作吗？

## 必交证据

- 预测与实际输出；
- 异常的 `ExecutionException.getCause()`；
- timeout 后的取消状态与任务观察到中断的证据；
- “Future 已取消但吞中断任务仍活着”的受控红证据；
- 关闭后拒绝提交、worker 存活数为 0；
- 虚拟线程身份、资源并发上限 2、普通计数 1 / 原子计数 2；
- 120 秒口述和一个未验证边界。

本实验不连接真实数据库，不测生产吞吐，不声称 2 秒适合业务 SLA，也不启用 JDK 25 `StructuredTaskScope` 预览 API。
