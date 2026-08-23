# 实验：提前 close 仍执行 finally

资源型生成器把 open/yield/finally 轨迹写入列表。验证器消费一项后显式 close，要求 cleanup 恰一次；另一路完全消费也恰一次。

```bash
./verify.sh
```
