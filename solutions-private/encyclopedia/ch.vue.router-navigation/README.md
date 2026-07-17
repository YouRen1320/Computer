# 私有参考：参数复用刷新

该参考只监听 `route.params.workOrderId`，把每次值映射到加载函数，并通过 `immediate` 支持直接深链接。`./verify.sh` 应转绿；它不代表真实 API、取消旧请求或浏览器 history 已验证。
