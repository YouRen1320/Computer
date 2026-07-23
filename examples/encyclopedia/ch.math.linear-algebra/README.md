# 线性代数正确示例

运行 `./verify.sh`。输入形状合同是 `features=(batch, feature)`、`weights=(feature, output)`、`bias=(output,)`，输出为 `(batch, output)`。脚本先用纯 Python 三重索引手算，再与 NumPy 逐元素比较，并验证非法形状会失败。
