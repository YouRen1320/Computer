# 原生报修表单与提交矩阵：离线示例

`report-form.html` 展示文本、选择、日期、文件及提交按钮的原生 HTML 合同；`submission-matrix.json` 先写出合法、缺失、格式错误、错误 name、绕过和重复提交的预测。所有内容是固定教学夹具。

```bash
./verify.sh
```

唯一验证器使用 Ruby 标准库检查 label/id、name/value、form method/action/enctype、约束和矩阵结构。它不启动浏览器或接收端，因此不会真正选择文件、发送 multipart、读取 ValidityState UI 或创建报修。

特别注意：本页 POST 到虚构的本地教学接收端，**不是** FactoryCare 生产 `/api/v1/reports`。生产合同使用 JSON `CreateReportRequest`，附件先走 upload-intent 流程，再以 `attachmentIds` 绑定；`observedDate` 也是本教材字段，不在当前生产请求中。真实验收必须另捕获浏览器 Network 请求并运行服务端校验/幂等测试。
