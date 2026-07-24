# 私有参考解：mounted 与生命周期

这份答案强调：mounted 保护 UI 更新，不提供请求去重或取消；真实取消还要验证底层 transport 与服务端边界。稳定 `Key` 维持元素身份，`didChangeDependencies` 则可能在依赖变化时再次调用，不能当成只执行一次的初始化钩子。
