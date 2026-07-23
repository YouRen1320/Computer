# NumPy shape、广播、溢出与 view 实验

实验故意复现四种故障：axis 选错、业务上错误但语法兼容的广播、int8 溢出和 basic slice 修改原数组；随后用 shape 断言、宽 dtype 与显式 copy 修复。

```bash
./verify.sh
```
