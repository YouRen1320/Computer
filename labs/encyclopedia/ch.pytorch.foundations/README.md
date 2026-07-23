# Foundations 故障实验

运行 `PYTHON_BIN=/path/to/python ./verify.sh`。实验注入不稳定 Dataset 返回结构、dtype 不一致、声明设备不一致、叶张量原地修改和忘记清梯度。设备故障只验证合同拒绝逻辑，不声称执行过 GPU 或 MPS。
