# 独立练习：补全浏览器请求矩阵

`answer.json` 故意把 Origin、SameSite、CORS、Cookie 和 cache 混在一起。第一次运行必须稳定红灯：

```bash
./verify.sh
```

只修改答案，不改 oracle。目标是能逐层回答“是否同源/同站、请求是否发送、Cookie 是否候选、是否预检、脚本是否可读、服务器是否仍需授权、cache 如何复用”。私有答案由同一公开 oracle 验证。
