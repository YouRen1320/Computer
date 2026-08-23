# Servlet 请求生命周期实验

本实验把两个容易被忽略的边界变成可重复测试：同一个 HttpServlet 实例可以并发服务多个请求，而异步工作不保证继续运行在原请求线程上。

运行 ./verify.sh 前先写下你的预测：

1. 24 个并发请求是否可能互相读到别人的 equipmentId？
2. 下游 Servlet 抛异常时，TraceFilter 的 finally 是否仍执行？
3. flushBuffer() 后还能否 resetBuffer()？
4. 切到命名 worker 后，哪些请求数据应该先复制成不可变值？

AsyncBoundary 故意只把 requestId 与 equipmentId 复制到小快照里，再提交后台任务；它没有把 HttpServletRequest 跨线程保存。同步测试适配器也明确返回 isAsyncSupported=false，防止实验把“可以开线程”误说成“容器已经启用 Servlet 异步”。

验证器固定使用 JDK 25、Maven 3.9.16、Jakarta Servlet 6.1，并以离线模式运行。

## 证据边界

实验能证明当前对象的并发隔离、finally 清理和线程切换行为；不证明真实容器的线程池大小、AsyncContext 超时策略、dispatch 映射或网络背压。
