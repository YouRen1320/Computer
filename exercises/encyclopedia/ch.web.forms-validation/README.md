# 公开练习：修复表单端到端契约

starter 的控件大多“看起来能用”，但故意把教学 form 指向生产 JSON 路径、启用 `novalidate`、漏掉 label/required、把 `priority` 写成 `severity`，并在 `answer.json` 中信任客户端校验与按钮防重。

```bash
./verify.sh
```

公开 starter **稳定退出 1**。请修改 `answer.html` 与 `answer.json`，不要修改 oracle 或 `expected-red.out`，也不要查看私有解。目标是让公开 oracle 绿灯，同时明确真实浏览器/接收端和生产适配层仍未验证。

本练习不要求实现 JavaScript 或服务器；任何“实际请求成功”都不能由离线文件宣称。完成后另在获批环境捕获 ValidityState、Network multipart 与服务端校验/幂等证据。
