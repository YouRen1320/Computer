# 副作用清理观察例

这个示例使用受控计时器模拟 FactoryCare 筛选请求。组件为每次 watch 运行创建独立 `AbortController`，在失效和卸载时清理，并通过 run ID 阻止陈旧提交；同时记录 mounted/updated/unmounted 以及 pre/post DOM 读取轨迹。

```sh
./verify.sh
```

验证覆盖 immediate、cleanup 顺序、最新结果、flush 时机、加载反馈和卸载归零。它不连接真实 API，因此不能证明服务器响应取消、网络超时、SSR 或真实读屏播报。

