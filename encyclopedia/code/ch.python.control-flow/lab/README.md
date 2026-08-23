# 实验：哨兵循环与循环不变量

程序从 stdin 读取优先级，`q` 结束。验证器检查第一项就是 q、混合输入、非法边界三种轨迹，并用 subprocess timeout 防止故障版无限循环。

```bash
./verify.sh
```
