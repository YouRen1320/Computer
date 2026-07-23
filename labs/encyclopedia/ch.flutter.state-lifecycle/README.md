# 实验：latest-wins 状态机

`operations.yml` 故意让后发请求 B 先完成，再让 A 完成。验证器模拟 `currentOperation == operation && mounted` 的提交规则，并确认旧 A 不覆盖 B。

```bash
./verify.sh
```
