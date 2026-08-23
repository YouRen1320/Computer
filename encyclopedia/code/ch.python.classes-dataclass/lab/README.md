# 共享状态、浅 frozen 与相等语义实验

实验先证明三类陷阱确实存在：类级 list 被实例共享、frozen 内嵌 list 仍可变、默认 dataclass 相等会把所有字段纳入比较；随后验证对应修复模型。

```bash
./verify.sh
```
