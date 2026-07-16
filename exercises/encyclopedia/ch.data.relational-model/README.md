# 练习：修正设备—工单关系答案

`answer.json` 是故意错误的 starter。只修改该文件，使其表达：

1. 工单行的唯一语义；
2. 设备与工单的稳定主键；
3. 外键从工单指向设备；
4. 设备 1 对 0..N 工单；
5. `resolved_at = NULL` 的含义与空字符串不同。

初始运行：

```sh
./verify.sh
```

应输出 `RELATIONAL EXERCISE STARTER EXPECTED FAILURE` 且脚本自身退出 0，证明红灯被正确观察，而不是把错误 starter 冒充完成。
