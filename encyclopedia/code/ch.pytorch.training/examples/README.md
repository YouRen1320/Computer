# 可复现训练循环正确示例

运行 `PYTHON_BIN=/path/to/python ./verify.sh`。脚本在 CPU 人工二维点上两次复跑相同种子，验证 `train/eval`、清梯度、加权指标、验证选择、带配置检查点恢复和测试集一次读取。损失变化只是回归 oracle，不代表真实工单质量。
