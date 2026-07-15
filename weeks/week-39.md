# 第 39 周：机器学习、深度学习与PyTorch概念复健

## 本周定位

本周补齐AI应用工程师应理解的模型基础，目的不是转算法岗。你需要能看懂数据、训练、指标、过拟合、推理和PyTorch代码，知道什么时候规则、传统模型、LLM或人工流程更合适。

## 前置条件

- Python工程化和pytest通过；
- 能使用NumPy/Pandas基础操作；
- 接受本周实验不进入FactoryCare生产路径，除非评估证明有价值。

## 本周目标

- 建立监督/无监督、训练/验证/测试和泛化概念；
- 理解分类、回归、聚类的任务边界和常见指标；
- 理解特征、标签、数据泄漏、类别不平衡和基线；
- 恢复PyTorch张量、autograd、Module、loss、optimizer和DataLoader；
- 完成一个小型可重复实验并诚实报告限制；
- 比较业务规则、传统模型、LLM和人工判断。

## 必须理解的概念

### 机器学习

- 监督、无监督、自监督和强化学习的高层区别；
- classification、regression、clustering和ranking；
- feature、label、sample和distribution；
- train/validation/test split、cross validation概念；
- overfitting、underfitting、bias/variance；
- data leakage、sampling bias和concept drift；
- baseline、ablation和可重复实验；
- accuracy、precision、recall、F1、ROC-AUC的适用性；
- 类别不平衡、阈值和业务成本；
- normalization/standardization和缺失值；
- 相关不等于因果。

### 深度学习/PyTorch

- tensor的shape、dtype、device和broadcast；
- forward、computation graph、autograd和gradient；
- `nn.Module`、parameter、loss、optimizer和learning rate；
- batch、epoch、shuffle、Dataset/DataLoader；
- train/eval模式、dropout/batch norm概念；
- `no_grad`/inference mode；
- checkpoint、state dict、保存/加载；
- CPU、GPU、Apple MPS和设备迁移；
- reproducibility、seed及其限制；
- 训练指标与线上业务指标不同。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务6，不在总时长之外重复增加。

### 任务1：概念地图（3小时）

- 画出数据→特征→训练→验证→测试→部署→监控流程；
- 为每个阶段写一个常见失败；
- 用维修工单举例precision与recall取舍；
- 解释为什么高accuracy可能没有业务价值。

### 任务2：传统基线实验（3小时）

- 构造或使用合规的小型工单文本/结构化数据；
- 先做规则或简单统计基线；
- 正确拆分数据，防止同一模板泄漏到训练/测试；
- 选择一个简单分类器，报告混淆矩阵和F1；
- 说明数据是合成/公开数据，不能代表真实工厂。

### 任务3：PyTorch最小训练（4小时）

- 创建Dataset/DataLoader；
- 建立小型网络或线性模型；
- 完成训练、验证、early stopping概念和checkpoint；
- 切换train/eval；
- 在CPU/MPS可用环境运行；
- 写一个shape错误和device错误的排查记录。

### 任务4：推理服务边界（2小时）

- 加载已保存模型并执行批量推理；
- 记录模型版本、输入schema和输出阈值；
- 讨论模型漂移、回滚、冷启动和依赖大小；
- 不把实验端点接入真实工单决策。

### 任务5：方案比较（2小时）

对“工单优先级建议”比较：

1. Java确定性规则；
2. 传统分类模型；
3. LLM结构化输出；
4. 调度员人工判断。

从数据量、可解释性、维护、成本、延迟、风险和回滚选择组合方案。推荐业务规则保底，AI只建议，人工负责高风险确认。

### 任务6：无AI与复盘（2小时）

- 关闭AI解释一次过拟合和数据泄漏；
- 手写一个训练/验证循环骨架；
- 更新算法岗与AI应用岗边界笔记。

## FactoryCare项目增量

本周只增加独立`ml-baseline`实验：

- 小型工单分类基线；
- 数据说明、拆分、指标和限制；
- PyTorch训练/推理脚本与测试；
- 规则/传统模型/LLM/人工方案比较ADR。

除非后续评估证明必要，不把该模型接入主业务。

## AI协作边界

AI可以解释公式、生成合成样例和审查训练循环，但不得：

- 自动选择指标后宣称模型优秀；
- 把训练集结果当测试结果；
- 使用来源不明或敏感数据；
- 编造准确率、线上提升和真实工业效果；
- 在不理解shape/device/梯度的情况下生成复杂网络。

## 无AI训练（120分钟）

给定二分类预测和真实标签，手工计算precision、recall、F1并解释不同阈值对“漏掉高风险工单”和“误报”的业务影响；再补一个PyTorch推理函数及测试。

## 求职动作（恢复求职后启用）

- 明确简历措辞：“了解ML/DL与PyTorch基础，主攻AI应用工程”；
- 不投要求模型训练、CUDA、论文或硕博研究背景的算法主岗作为主线；
- 模拟回答：RAG是不是训练？Embedding是不是大模型微调？传统模型何时优于LLM？

## 交付物

- [ ] ML生命周期概念图；
- [ ] 传统基线和指标报告；
- [ ] PyTorch训练、checkpoint和推理脚本；
- [ ] 数据/指标限制说明；
- [ ] 四方案ADR；
- [ ] 无AI题和周复盘。

## 验收标准

- 能解释训练、验证、测试和线上监控；
- 能识别至少三类数据泄漏；
- 能根据业务选择precision/recall等指标；
- 能阅读并修改基础PyTorch训练循环；
- 实验可重复，数据和限制明确；
- 不将本周实验包装成算法生产经验。

## 本周明确不做

- Transformer推导和论文复现；
- 大模型预训练/微调；
- CUDA、分布式训练和MLOps平台；
- 用合成数据宣称可预测真实设备故障；
- 为了“全面”学习所有算法。

## 官方资料

- [PyTorch Learn the Basics](https://docs.pytorch.org/tutorials/beginner/basics/intro.html)
- [PyTorch autograd](https://docs.pytorch.org/tutorials/beginner/blitz/autograd_tutorial.html)
- [scikit-learn model evaluation](https://scikit-learn.org/stable/modules/model_evaluation.html)
- [scikit-learn common pitfalls](https://scikit-learn.org/stable/common_pitfalls.html)
