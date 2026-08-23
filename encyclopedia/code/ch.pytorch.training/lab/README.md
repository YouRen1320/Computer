# 训练故障实验

运行 `PYTHON_BIN=/path/to/python ./verify.sh`。实验区分 `model.eval()` 与禁用梯度，暴露 Dropout 模式遗漏、验证反向传播、测试集重复读取和缺配置检查点。全部只在 CPU 人工输入上验证。
