# Lab：优先级分支与有界循环边界表

`src/priority.mjs` 每次只处理一个命令行案例：`node src/priority.mjs <score> <retryCount>`。唯一 verifier 覆盖零次、一次、多次、阈值、上下界和两类非法输入，再确认 truthiness、遗漏分支和 off-by-one 三个故障稳定失败。

```sh
./verify.sh
```

输入拒绝使用 stdout 固定错误码、空 stderr 和退出码 2；未捕获异常不是预期输入校验。教学优先级不替代 FactoryCare 后端状态机。
