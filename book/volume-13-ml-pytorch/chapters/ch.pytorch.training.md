---
schema_version: 2
edition: 2026.2-draft
id: ch.pytorch.training
title: 训练循环、复现、过拟合、评估与调参
responsibility: 实现可复现的 PyTorch 训练与验证循环，识别欠拟合和过拟合并保存检查点，不把测试集用于调参。
volume: '13'
order: 14
level: L3
status: drafting
path: book/volume-13-ml-pytorch/chapters/ch.pytorch.training.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.pytorch.foundations
version_surfaces:
- python-3.14
- pytorch-stable
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“训练循环、复现、过拟合、评估与调参”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - pytorch-training-loop
  - pytorch-repro-tuning
  covers_topics:
  - pytorch.train-eval-mode
  - pytorch.optimizer-step
  - pytorch.validation-loop
  - pytorch.metric-aggregation
  - pytorch.random-seed
  - pytorch.checkpoint
  - pytorch.early-stopping
  - pytorch.hyperparameter-search-boundary
  uses_capabilities:
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 训练工单分类网络，保存配置、种子、曲线、最佳验证检查点和测试集一次性评估报告；独立保存可复现工件与判断结果
  covers_topic_groups:
  - pytorch-training-loop
  - pytorch-repro-tuning
  covers_topics:
  - pytorch.train-eval-mode
  - pytorch.optimizer-step
  - pytorch.validation-loop
  - pytorch.metric-aggregation
  - pytorch.random-seed
  - pytorch.checkpoint
  - pytorch.early-stopping
  - pytorch.hyperparameter-search-boundary
  uses_capabilities:
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: reproducibility-run-curve-analysis-checkpoint-resume
- id: diagnose
  kind: fault-diagnosis
  text: 面对“遗漏 train/eval 切换、验证阶段累计梯度、测试集参与调参或检查点缺少配置”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - pytorch-training-loop
  - pytorch-repro-tuning
  covers_topics:
  - pytorch.train-eval-mode
  - pytorch.optimizer-step
  - pytorch.validation-loop
  - pytorch.metric-aggregation
  - pytorch.random-seed
  - pytorch.checkpoint
  - pytorch.early-stopping
  - pytorch.hyperparameter-search-boundary
  uses_capabilities:
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 训练循环、复现、过拟合、评估与调参

一次 forward/backward 只证明梯度路径存在。训练需要反复读取训练批次、清梯度、前向、计算损失、反向和更新参数；每轮之后在独立验证集评估，用验证证据选择检查点和停止时机；所有选择完成后才允许读取一次测试集。本章把这些步骤写成可复现、可恢复、可审查的合同。

本章人工二维点被命名为“玩具工单分类”仅为连接项目语境，不是实际工单数据。损失下降、分类准确或最佳 epoch 都不能解释为真实模型质量。工件只在 CPU、固定小数据和当前隔离版本上验证循环行为，不声称 GPU/MPS 训练、线上延迟或可部署性。

## 1. 训练、验证、测试三种职责

训练集用于计算梯度并更新参数；验证集用于比较超参数、选择 epoch、早停和模型版本；测试集只在全部选择冻结后做一次最终估计。三者来自同一问题合同但扮演不同角色。

如果每次改学习率都看测试分数，测试集实际上已经参与调参，最终报告会偏乐观。即使从未调用 backward，反复根据测试结果作决定也构成信息泄漏。边界由“是否影响选择”决定，不由代码是否叫 `test_loader` 决定。

### 1.1 切分先于训练

样本单位、分层、时间顺序和泄漏风险应在前置机器学习章节确定。训练循环不应临时随机切分来获得更好曲线。真实工单可能同一设备多条记录相关，随机行切分会让同一实体跨集合。

### 1.2 数据版本冻结

复现实验需要知道每个集合的精确版本或摘要。若运行期间训练集更新，种子相同也无法复现。工件使用代码内固定人工 Tensor，避免把外部数据变化混进循环验证。

## 2. 一轮训练的顺序合同

经典最小批训练顺序：

```text
model.train()
for features, labels in train_loader:
    optimizer.zero_grad(set_to_none=True)
    logits = model(features)
    loss = criterion(logits, labels)
    loss.backward()
    optimizer.step()
```

顺序不是格式偏好。清梯度应在当前反向前完成；`backward` 产生参数梯度；`step` 根据这些梯度改参数。先 step 后 backward 使用不到当前批梯度，忘记 zero 会把此前批次累加进来。

### 2.1 model.train()

训练模式影响 Dropout、BatchNorm 等有模式模块。它不打开 Autograd；梯度记录默认由 grad mode 决定。每个训练 epoch 显式调用 `train()`，避免上一次验证留下 eval 状态。

### 2.2 optimizer.zero_grad

PyTorch 梯度默认累加。本章显式 `set_to_none=True`，每个批次重新建立状态。若设计梯度累积，应把微批次数、损失缩放和 step 频率写进配置，而不是删除 zero 后称作优化。

### 2.3 forward 与 loss

分类模块输出 `(B,C)` logits，标签 `(B,)` int64，交叉熵返回标量。先断言形状与有限性，再反向。损失定义是训练目标，不一定等同业务指标；低损失也不自动等于业务收益。

### 2.4 backward 与有限梯度

反向后遍历参数，检查预期可训练参数梯度存在且有限。某些条件分支可能使部分参数本轮无梯度，应由模型合同决定。NaN/Inf 首次出现的位置比最后失败 epoch 更可信。

### 2.5 optimizer.step

优化器读取 `.grad` 修改参数，通常在 no-grad 语义下执行。更新后不应继续复用更新前的计算图。学习率、动量和权重衰减都属于实验配置并进入检查点。

## 3. 验证循环

验证不更新参数：

```python
model.eval()
with torch.inference_mode():
    for features, labels in validation_loader:
        logits = model(features)
        loss = criterion(logits, labels)
```

`eval()`切换模块行为，`inference_mode()`禁止图记录并减少相关开销，它们职责不同。只写 eval，输出仍可能 `requires_grad=True`；只禁用梯度，Dropout 仍可能随机丢弃。

### 3.1 验证阶段不要 backward

若忘记禁用图并错误调用 backward，参数 `.grad` 会被验证数据污染。下一训练批即使之后清零可能浪费资源；若清零位置也错，验证梯度会参与更新。测试在验证前清为 None、验证后仍全为 None。

### 3.2 不能在验证中调参数

验证只读模型。不能偷偷做 BatchNorm 统计更新、梯度 step 或基于单个样本改阈值。所有校准步骤也属于模型选择，需有自己的训练/验证合同。

## 4. 指标聚合

批次损失常是该批平均。若最后一个批次更小，直接平均各批 loss 会给小批次同等权重。正确全样本平均：

```text
loss_sum += batch_mean_loss × batch_size
count += batch_size
epoch_loss = loss_sum / count
```

准确率累计正确数再除总样本数。对 F1、AUC 等非可加指标，不能简单平均批次结果；应累计必要预测/混淆计数后统一计算。

### 4.1 同时记录分子与分母

只保存 0.8 不知道是 4/5 还是 8000/10000。证据至少包含样本数、过滤规则和指标版本。缺失标签、最后批、类别不平衡都会影响解释。

### 4.2 损失与业务指标分开

损失用于优化，指标用于评估某类表现。交叉熵下降时准确率可能不变，因为概率置信度变化但 argmax 未变。不能为让曲线好看把两者混成一个名称。

## 5. epoch、step 与记录

step 通常是一次优化器更新，epoch 是训练集被遍历一次。样本数、batch size、`drop_last` 和梯度累积会改变每 epoch step 数。报告“训练 30 轮”必须同时记录数据量与批次配置。

每轮曲线建议保存：epoch、训练 loss/指标、验证 loss/指标、学习率、用时、是否刷新最佳、停止原因。日志是实验事实，不是模型质量结论。

### 5.1 不要只保存最后点

最后模型未必验证最佳。曲线能看到学习失败、过拟合迹象、异常突跳和恢复情况。检查点应在验证判据改善时保存，最后恢复最佳而不是最后 epoch。

## 6. 欠拟合与过拟合的证据模式

欠拟合常表现为训练和验证都差，可能容量不足、特征无信息、训练不够或实现错误。过拟合常表现为训练继续改善而验证停止改善甚至变差。它们是诊断模式，不是仅凭一张曲线自动下结论。

### 6.1 先排实现错误

训练 loss 不降可能是标签错、梯度为零、学习率不合适或模式错误，不应马上增加网络。验证差也可能来自预处理不一致或切分分布差异。先用极小数据能否过拟合作为管道检查，但小数据记忆成功不等于泛化。

### 6.2 曲线需要相同口径

训练 loss 常在参数不断更新的多个批次上平均，验证 loss 在 epoch 末固定参数上计算，二者不是完全同步的同一测量。若 Dropout 与数据增强仅训练启用，差异更大。解释时明确测量流程。

### 6.3 不以测试曲线诊断

测试集不应每轮绘曲线，否则它参与了早停和选择。过拟合判断使用训练与验证；测试只输出冻结方案的最终报告。

## 7. 随机种子与复现

最低限度记录 Python、PyTorch、依赖、设备、数据版本、代码版本、随机种子、模型配置和训练配置。示例同时设置 Python random、`torch.manual_seed` 和 DataLoader CPU Generator。

### 7.1 同种子不是跨环境保证

PyTorch 官方复现说明指出，不同版本、提交、平台或 CPU/GPU 之间不保证完全相同；某些算子也可能非确定。种子控制随机序列的一部分，不冻结算法和硬件。

本章实际 oracle 很窄：在 Python 3.14.3、PyTorch 2.13.0、CPU、固定人工数据上，两次独立构建与训练得到完全相同最佳 epoch、权重和关键数值。它不证明 GPU/MPS，也不代表大型模型能逐位复现。

### 7.2 复现失败的排查顺序

先比较数据和配置，再比较首个批次索引、初始 state_dict、第一步 logits/梯度/参数，定位最早分叉，而不是只看最终准确率。保存随机状态可帮助恢复，但版本差异仍可能存在。

## 8. 检查点

仅保存 `model.state_dict()`足以在已知同一结构时做权重恢复，却不足以完整恢复训练。本章训练检查点包含：

- schema 版本；
- 模型构造配置；
- 训练配置与种子；
- model state；
- optimizer state；
- epoch 与最佳验证值。

恢复时先验证必需键和 schema，再按配置构造模型、严格加载状态。若要继续完全相同的随机轨迹，还需调度器和随机状态等更多信息；本章没有声称完整的任意中断续训。

### 8.1 最佳与最新检查点

最佳检查点用于验证判据最优模型，最新检查点用于故障恢复，职责不同。一个文件覆盖另一个会丢证据。教材只保存最佳以满足当前 oracle，生产设计应区分名称和保留策略。

### 8.2 加载安全

模型文件是外部输入。不要加载不可信 pickle 制品。当前示例使用 `torch.load(..., weights_only=True)` 读取由本程序写入、只含基础容器和 Tensor 的检查点，并固定 `map_location="cpu"`。具体默认与支持类型随版本变化，应按官方序列化文档复核。

## 9. 早停

早停监控验证指标，当若干 epoch 无改善后停止。需要定义方向、最小改善量、耐心值、起始轮和并列处理。没有这些，“连续 5 轮没变”会因浮点噪声产生歧义。

早停本身是超参数选择，会让验证集信息进入模型选择，这是允许的验证职责；不能再把同一验证结果当完全独立最终估计。测试集保留为最终一次评估。

### 9.1 恢复最佳而非停止点

耐心期间模型可能已从最佳位置走远。停止后加载最佳检查点，再执行最终测试。工件验证检查点可恢复且测试门读取一次。

### 9.2 小实验不强求触发

示例最大 30 epoch，若验证持续改善，早停不触发也不是错误。测试应验证最大轮数、曲线长度与最佳保存，而不是伪造“过拟合发生”。

## 10. 调参边界

超参数包括学习率、batch size、隐藏宽度、正则、阈值、最大 epoch等。调参过程必须记录搜索空间、预算、选择指标、种子策略和失败运行，避免只报告最好一次。

### 10.1 不把测试集放进搜索

实现一个测试集门：第一次最终读取计数从 0 到 1，再读直接报错。它不能防止所有人为复制数据，但能把流程契约变成可测试行为。搜索函数只接受训练和验证 loader，不接收测试 loader，是更强接口设计。

### 10.2 多次尝试也会过拟合验证集

尝试越多，越可能偶然选中验证噪声。需要限制预算、使用交叉验证或另留校准集，并在报告中披露选择次数。不能因为测试只读一次，就忽略验证过拟合。

### 10.3 失败运行也是证据

NaN、超时和资源不足不能从搜索历史删除，否则比较偏向幸存配置。保存状态和原因，不把它们当准确率 0 混入指标。

## 11. 一个可审查实现

示例的 `run_experiment` 顺序：冻结配置与人工切分；设置 CPU 随机源；构建训练/验证 loader；构造模型和 SGD；逐 epoch 训练与验证；按验证 loss 保存带配置最佳检查点；达到早停或最大轮数；重新加载最佳；通过门读取测试一次。

两次运行分别写入独立临时目录，防止第二次复用第一次制品。比较最佳 epoch、曲线长度、最佳验证值和恢复后的每个 state_dict Tensor。成功只说明本地回归合同成立。

### 11.1 为何不输出真实准确率宣传

人工数据由一条简单规则构造，分数没有外部意义。即使测试准确率为 100%，也只说明模型拟合了四条设计样本。工件打印版本、复现与读取次数，不把玩具准确率作为成果。

## 12. 四类故障的首证据

### 12.1 漏掉 train/eval

Dropout 在训练模式重复同输入可不同，eval 后应稳定。首证据是 `model.training` 和相同输入的两次输出，不是最终指标波动。修复时每个训练/验证入口显式设模式。

### 12.2 验证累计梯度

`eval()` 后普通 forward 仍 `requires_grad=True`，错误 backward 会填充 `.grad`。首证据是验证输出的 grad 标志及验证后参数 grad 非 None。修复为 inference/no_grad 上下文并禁止 backward。

### 12.3 测试参与调参

代码可能不抛错，首证据是访问日志/计数超过 1，或搜索函数收到 test loader。修复流程与接口，重新从未触碰测试的实验开始；仅删除日志不能恢复独立性。

### 12.4 检查点缺配置

只有权重时无法证明用哪个结构、预处理和训练设置。首证据是加载前必需键校验。修复导出合同并重新生成，不能凭当前代码猜历史配置。

## 13. 怎样审查一组训练曲线

曲线审查不能只问“最后是否更低”。先确认横轴是 epoch 还是 step，纵轴是批平均、全样本平均还是滑动平均；训练与验证是否在同一模型状态和同一损失定义下计算；缺失 epoch、重启拼接和异常值是否标注。

### 13.1 从第一轮就完全不变

可能是学习率为零、参数未交给优化器、loss 与参数断图、忘记 backward、梯度全零或日志反复打印缓存值。首查一次 step 前后参数差、命名参数 grad、optimizer 参数组和第一批输入输出。不要立即训练更多轮。

### 13.2 训练与验证同时稳定改善

说明当前测量下优化在进行，但仍不能证明切分无泄漏、指标满足业务或未来数据泛化。继续保存最佳验证检查点，并观察是否进入平台。曲线好看不是数据合同审计的替代品。

### 13.3 训练改善而验证恶化

这是过拟合候选模式，也可能是训练/验证预处理漂移、eval 模式遗漏、验证标签错误或聚合口径改变。先固定同一检查点在两个集合上做小样本手查，再考虑正则、容量、更多数据或早停。

### 13.4 两条曲线剧烈波动

排查 batch 太小、学习率过大、输入异常、随机增强、指标样本过少和状态泄漏。保存 batch 级日志只用于定位，避免把高频噪声包装成 epoch 结论。若出现 NaN，定位首次非有限的输入、激活、loss、grad 或参数。

### 13.5 选择判据必须事先确定

若先看曲线再决定“这一轮看 accuracy、下一轮看 loss”，就增加了隐性搜索。配置中明确主验证指标、方向和并列规则；其他指标作为诊断，不随结果临时更换冠军规则。

## 14. 中断、恢复与“可复现”层级

“从头同种子复跑”“从检查点继续”“仅加载最佳模型评估”是三种不同能力。本章验证第一种和第三种：从头两跑状态相同；最佳 state 能重新构造模型并评估。没有保存所有随机数与采样器进度，所以不宣称在任意 batch 中断后逐位延续。

### 14.1 完整续训通常还需要什么

除了模型与优化器，还可能需要学习率调度器、梯度缩放器、当前 epoch/step、Python/PyTorch/NumPy随机状态、DataLoader 采样器状态、早停计数、数据版本和配置摘要。若有梯度累积，还要保存当前累积相位或只在安全边界检查点。

### 14.2 原子写入

进程在写文件中途退出可能留下截断制品。稳健做法是先写临时文件、刷盘并验证，再原子替换目标；同时保留上一份可用检查点。本章临时目录和小文件没有模拟崩溃安全，因此这项明确为生产非目标。

### 14.3 恢复验证

不能因为 `torch.load` 未报错就判恢复成功。重建模型后应严格加载键，核对配置与 schema，用固定黄金批次比较保存前后 logits，并确认 epoch、最佳指标和优化器状态可读。下一章会把这种 round trip 提升为推理制品合同。

### 14.4 代码版本

同名 Python 类后来改结构时，旧 state_dict 可能键不匹配，也可能形状恰好兼容却语义改变。检查点记录模型配置和制品 schema，代码仓库另记录提交或构建版本。不能靠文件名 `best.pt` 猜来源。

## 15. 训练循环的测试金字塔

第一层是纯函数与合同测试：指标聚合、配置校验、测试门和检查点必需键。它们快且失败定位明确。第二层是单批集成测试：固定模型与批次，确认 forward、loss、backward、step 后参数改变且有限。第三层是小数据端到端：若干 epoch、验证、最佳保存与恢复。第四层才是更昂贵的完整实验。

### 15.1 单批更新 oracle

保存 step 前参数副本，执行一次训练步，至少一个需要梯度的参数应改变；所有参数与梯度有限。若学习率明确为零，则“不改变”是预期，但要在配置测试中标明。只检查 loss 数字可能遗漏 optimizer 没更新。

### 15.2 模式测试

含 Dropout 的模块在 train 与 eval 行为不同。测试先断言 `model.training`，再在固定输入下观察模式。不要依赖一次随机输出恰好不同作为唯一证据；状态标志、重复输出和禁用图共同验证。

### 15.3 指标测试

构造两个不同大小批次，手算全样本 loss 与正确数，证明聚合按样本加权。使用所有批次大小相同的数据会让“批均值再平均”的错误偶然通过。

### 15.4 检查点测试

故意删除 `model_config`，验证加载边界先红；恢复后重新保存、加载并比较黄金输入。测试未知 schema、形状不匹配和损坏文件。不要捕获所有异常后返回随机初始化模型，那会制造静默错误。

### 15.5 测试集访问测试

门对象初始读数 0，最终评估后为 1，第二次访问明确失败。更高层审查搜索代码的函数签名，确保测试对象根本不在调参作用域。技术保护与流程审查共同工作。

## 16. 资源、性能与当前非目标

完整训练还涉及多进程加载、线程、混合精度、编译、分布式、加速器内存和断点容错。它们会改变性能和复现表面，但不应在基础循环未验证前加入。先让 CPU 小数据 oracle 透明，再逐项增加一种复杂性及对应故障测试。

本章没有测 GPU/MPS，也没有报告训练耗时阈值。临时 CPU 运行快慢受机器负载、线程和框架构建影响，不能外推成本。没有真实数据，因此不做公平性、线上漂移或业务 ROI 结论；这些有独立章节与证据门。

## 17. FactoryCare 边界

真实业务中 Java 后端拥有工单事实、标签定义、权限和状态；Python 训练读取经授权、冻结、有时间切分版本的数据，产出检查点和离线报告。模型不得直接更改工单状态，测试指标不得自动成为人员考核。

训练配置还要记录特征合同、标签截止时间和模型用途。客户端不直连训练服务。任何上线决定需要独立评审、推理制品、监控、人工兜底和回滚；本章不实施这些环节。

## 18. 版本表面

仓库 `pytorch-stable` 为 provisional。截至 2026-07-24，稳定文档路由到 PyTorch 2.13，而 Get Started 页面仍显示较旧稳定文字；本章不会消除这项来源不一致。实际 CPU 验证环境是 Python 3.14.3、PyTorch 2.13.0、pytest 9.1.1。

训练/验证分离、梯度清零、测试最终一次使用是稳定工程原则；`zero_grad`默认、`torch.load`安全默认、确定性开关和可用设备是版本/环境表面。升级后重新执行同种子双跑和检查点恢复。

## 19. 可运行工件

- `examples/encyclopedia/ch.pytorch.training/`：两次 CPU 训练、最佳检查点恢复与测试一次门。
- `labs/encyclopedia/ch.pytorch.training/`：模式、验证梯度、测试复用、缺配置检查点故障。
- `exercises/encyclopedia/ch.pytorch.training/`：验证入口故意未 eval 且仍构图，初始红灯。
- `solutions-private/encyclopedia/ch.pytorch.training/`：组合 eval 与 inference_mode。

## 20. 120 秒复述模板

“训练循环每批先清梯度，再前向、损失、反向和 step；训练入口设 train。验证入口设 eval，并禁用梯度，按样本数聚合指标。验证集选择超参数、最佳 epoch和早停，测试集在所有选择冻结后只读一次。复现要记录数据、代码、版本、设备、配置和种子，同种子也不保证跨平台。检查点至少带 schema、模型/训练配置、模型和优化器状态及 epoch。越界反例是反复查看测试分数来选学习率，再把该测试分数当独立结果；它已经泄漏。本章 CPU 玩具曲线不代表真实质量。”

## 21. 自测题

1. `zero_grad`、forward、backward、step 的顺序是什么？
2. eval 与 inference_mode 分别解决什么？
3. 为什么不能直接平均每批平均 loss？
4. 训练 loss 降、验证升能否立即证明过拟合？
5. 测试集没有 backward，为何仍可能泄漏？
6. 种子相同为何不保证跨版本一致？
7. 只保存 model_state 缺少哪些恢复信息？
8. 早停后为什么加载最佳而非停止点？
9. 两次验证访问是否违反最终测试一次规则？
10. 人工数据 100%准确为何不是生产证据？

## 22. 答案要点

1. 清梯度、前向、loss、反向、更新。
2. eval 切模块行为；inference_mode 禁止图记录。
3. 最后批可能更小，需按样本数加权。
4. 不能，先排口径、预处理、模式和实现错误，再结合多轮模式。
5. 只要结果影响选择，信息就进入方案。
6. 算法、算子、硬件和依赖可能变化，官方不作全局保证。
7. 结构、训练配置、优化器、epoch、schema、随机状态等。
8. 耐心阶段可能离最佳点更远。
9. 验证本来可多次；规则约束独立测试集。
10. 数据按规则设计、样本极小且无真实分布代表性。

## 23. 官方资料

- [优化参数教程](https://docs.pytorch.org/tutorials/beginner/basics/optimization_tutorial.html)：训练/测试循环、损失与优化器基础。
- [复现说明](https://docs.pytorch.org/docs/2.13/notes/randomness.html)：随机性、确定性与跨环境限制。
- [Module 参考](https://docs.pytorch.org/docs/2.13/generated/torch.nn.Module.html)：`train()`/`eval()`行为入口。
- [Autograd grad mode](https://docs.pytorch.org/docs/2.13/notes/autograd.html)：训练、no-grad 与 inference mode 的区别。
- [序列化语义](https://docs.pytorch.org/docs/2.13/notes/serialization.html)：state_dict、保存与加载边界。

核对日期 2026-07-24。官方资料说明框架表面，本章工件的人工数据和 CPU 复跑提供本地行为证据，两者不可互相替代。
