# 实验：表单契约故障与同矩阵重跑

本实验把正确表单、提交预测矩阵与三类故障记录放在同一目录。先运行基线，再在副本中依次删除 label 关联、把 `priority` 的 name 改成 `severity`、用受控接收端绕过客户端校验。每次只改一个变量，保存首个差异，修复后运行完全相同的命令。

```bash
./verify.sh
```

唯一验证器只做离线结构与记录核对。`submission-matrix.json` 中的请求/服务端结果是待真实环境验证的预言，不是伪造的浏览器抓包。正式 G4 证据需在本地受控 HTTP 接收端和锁定浏览器中捕获 ValidityState、是否发请求、raw payload 与服务端结果。

此 lab 的 multipart endpoint 只用于教学。FactoryCare 生产仍是 JSON 创建报修、独立 upload-intent 与 `attachmentIds`，并由服务端执行权限、校验和 `Idempotency-Key`。
