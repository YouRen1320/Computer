# 表单合同观察例

这个示例把 FactoryCare 的报告创建界面作为受控表单，保存 DOM、Vue 模型、客户端错误和 `CreateReportRequest` 快照。界面标题写“提交报告并创建初始工单”，真正负载只投影 `POST /api/v1/reports` 允许的字段。

```sh
./verify.sh
```

验证覆盖文本/数字转换、radio/select、checkbox 数组、非法提交、精确负载和完整重置。Happy DOM 只提供确定的 DOM 观察环境；真实输入法、移动浏览器原生校验气泡、自动填充、读屏和 API 鉴权仍需另测。

