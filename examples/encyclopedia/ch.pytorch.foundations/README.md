# Tensor、Dataset、Module、Autograd 正确示例

运行 `PYTHON_BIN=/path/to/python ./verify.sh`，该解释器必须安装 PyTorch。脚本只在 CPU 上创建四条人工数据，验证 Dataset 返回模式、DataLoader 批次、两层 Module 的形状、全部参数有限梯度、同种子重复结果和梯度清零合同；不验证 GPU/MPS 或模型质量。
