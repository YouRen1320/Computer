# pandas dtype、缺失、CoW 与 merge 基数实验

实验复现隐式字符串数值、缺失比较、派生表赋值不回写原表，以及 2×2 多对多连接膨胀；再用失败掩码、`isna`、单步 `loc` 和 `validate` 修复。

```bash
./verify.sh
```
