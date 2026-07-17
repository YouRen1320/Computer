# 语义化工单详情：离线示例

本目录演示一页不依赖 CSS、表单、脚本或 ARIA 补丁的静态 FactoryCare 工单详情。`page.html` 的数据是固定教学夹具，`expected.json` 是在查看检查结果之前写下的元数据、区域和标题预言。

运行：

```bash
./verify.sh
```

唯一的 `verify.sh` 调用 Ruby 标准库检查课程约定并与 `expected.out` 比较；它不联网、不启动浏览器。绿灯只证明：DOCTYPE、语言、head 元数据、原生区域、显式标题序列、若干文本语义和四类意图注释符合本示例契约。

它不是完整 HTML conformance checker，也没有读取浏览器 DOM/可访问性树。正式证据仍需补充目标浏览器版本、HTML checker 输出、Elements/Accessibility 截图和读屏器标题/区域导航任务。夹具不含真实租户、工单或个人信息。
