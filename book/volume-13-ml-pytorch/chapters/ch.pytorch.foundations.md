---
schema_version: 2
edition: 2026.2-draft
id: ch.pytorch.foundations
title: Tensor、Dataset、Module 与 Autograd
responsibility: 把神经网络数学映射到 PyTorch Tensor、Dataset、Module 和 Autograd 合同，区分数据、参数、梯度和设备，不实现完整训练流程。
volume: '13'
order: 13
level: L3
status: drafting
path: book/volume-13-ml-pytorch/chapters/ch.pytorch.foundations.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ml.neural-networks
- ch.ml.metrics-validation
- ch.python.classes-dataclass
version_surfaces:
- python-3.14
- numpy
- pytorch-stable
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Tensor、Dataset、Module 与 Autograd”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - pytorch-tensor-data
  - pytorch-module-autograd
  covers_topics:
  - pytorch.tensor-dtype-device
  - pytorch.tensor-shape-view
  - pytorch.dataset-dataloader
  - pytorch.batch-collation
  - pytorch.module-parameter
  - pytorch.forward-contract
  - pytorch.autograd-graph
  - pytorch.grad-zeroing
  uses_capabilities:
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  - math.linear-calculus
  - python.language
  - data.numpy-pandas
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Tensor、Dataset、Module 与 Autograd”构建可运行程序与测试：实现自定义 Dataset 与两层 Module，预测每层形状，运行一次前向和反向并核对参数、梯度与设备；独立保存可复现工件与判断结果
  covers_topic_groups:
  - pytorch-tensor-data
  - pytorch-module-autograd
  covers_topics:
  - pytorch.tensor-dtype-device
  - pytorch.tensor-shape-view
  - pytorch.dataset-dataloader
  - pytorch.batch-collation
  - pytorch.module-parameter
  - pytorch.forward-contract
  - pytorch.autograd-graph
  - pytorch.grad-zeroing
  uses_capabilities:
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  - math.linear-calculus
  - python.language
  - data.numpy-pandas
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: tensor-assertions-gradient-check-dataset-contract-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“原地操作破坏计算图、忘记清梯度、dtype/设备混用或 Dataset 返回模式不稳定”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - pytorch-tensor-data
  - pytorch-module-autograd
  covers_topics:
  - pytorch.tensor-dtype-device
  - pytorch.tensor-shape-view
  - pytorch.dataset-dataloader
  - pytorch.batch-collation
  - pytorch.module-parameter
  - pytorch.forward-contract
  - pytorch.autograd-graph
  - pytorch.grad-zeroing
  uses_capabilities:
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  - math.linear-calculus
  - python.language
  - data.numpy-pandas
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Tensor、Dataset、Module 与 Autograd

前面的数学章节用数组、矩阵和链式法则描述神经网络。本章把这些概念映射到 PyTorch：`Tensor` 保存数值、形状、数据类型和设备；`Dataset` 定义一个样本怎样取得；`DataLoader` 负责抽取与拼批；`nn.Module` 注册子模块和参数并定义前向合同；Autograd 根据实际执行的张量运算构建计算图并求梯度。

本章只完成一次可审查的前向与反向，不实现完整训练循环，不选择超参数，不报告模型效果，也不部署服务。所有工件明确使用 CPU 人工小数据。即使当前机器可能存在其他后端，本章没有实际验证 GPU 或 MPS，因此不会声称这些设备可用、等价或更快。

## 1. PyTorch 解决什么问题

NumPy 已能做矩阵运算，但神经网络还需要自动计算大量参数的梯度、统一组织参数和子层、批量加载数据、在不同计算设备间迁移。PyTorch 把这些能力组合为一个框架。核心流程仍是数学：输入经过函数得到预测，预测与目标形成标量损失，链式法则给参数梯度。

框架不会替你保证语义正确。把“告警数”和“设备年龄”列交换，Tensor 形状仍可能合法；标签映射反了，损失仍会下降；Dataset 返回不稳定结构，可能直到某个批次才失败。必须先有数据、形状、dtype、设备和输出合同，再调用框架。

### 1.1 数据、参数、梯度、状态

这四类对象要分清：

- 数据是输入与目标，通常不需要梯度。
- 参数是模型要学习的 Tensor，由 Module 注册，通常 `requires_grad=True`。
- 梯度是损失对参数的导数，反向后存入参数的 `.grad`。
- 状态还包括缓冲区、模块训练/评估模式、随机数状态等，不一定是可训练参数。

把梯度当参数值、把标签设为需梯度、或只保存权重却忘记模型配置，都是边界混淆。

## 2. 版本与运行环境先分开记录

仓库版本注册表把 `pytorch-stable` 写成“支持 Python 3.14 的当前稳定版”，状态是 `provisional`，不是 `verified`。截至 2026-07-24，PyTorch 官方稳定文档链接跳转到 2.13 文档，当前隔离 CPU 环境通过包解析实际安装并验证的是 Python 3.14.3、PyTorch 2.13.0、NumPy 2.5.1、pytest 9.1.1。然而官方 Get Started 页面同日仍显示“Stable (2.7.0)”文字，官方入口之间存在明显不同步。

因此本章不把单一页面或本地解析结果升级成全局版本结论。安装前以目标操作系统、Python 版本和官方选择器重新核对；锁定依赖后在实际环境运行测试。正文讲的 Tensor、Module、Dataset、动态计算图等长期概念相对稳定，但具体 API、默认参数、序列化安全默认、支持后端和复现限制都是版本表面。

当前全局 Python 原本没有 `torch` 和 `pytest`；实际证据来自临时隔离 CPU 环境，不等于全局环境已配置。教材的 `verify.sh` 支持用 `PYTHON_BIN` 指向已安装依赖的解释器。

## 3. Tensor：不只是多维数组

Tensor 至少携带四项关键信息：数值、`shape`、`dtype`、`device`。若参与自动求导，还要关注 `requires_grad`、是否为叶张量、产生它的运算和版本状态。

```python
import torch

x = torch.tensor([[1.0, 2.0], [3.0, 4.0]],
                 dtype=torch.float32,
                 device="cpu")
```

这里形状 `(2,2)`、dtype `float32`、设备 CPU。不要依赖默认 dtype 猜测；输入、参数和损失应有显式合同。

### 3.1 dtype

常见特征使用浮点数，类别标签用于交叉熵时通常是 `torch.int64` 类别索引。若把输入构造成 `float64`，而线性层参数为默认 `float32`，矩阵乘法会在前向阶段因 dtype 不一致失败。把两者都随意转成整数更糟，因为神经网络多数浮点算子和梯度不适用整数参数。

转换可用 `.to(dtype=torch.float32)`，但应该在明确的数据边界做一次，而不是每层看到错误就强制转换。后者会隐藏上游合同漂移并产生额外复制。

### 3.2 device

设备说明 Tensor 的存储与计算位置。模块参数和输入必须位于兼容设备。基础模式：

```python
device = torch.device("cpu")
model = model.to(device)
features = features.to(device)
```

不要只移动模型或只移动输入。设备可用性是运行时事实，必须实际查询和执行；本章只固定 CPU。故障实验通过“期望设备与实际 CPU 不同”的合同检查暴露问题，但没有在虚构 GPU/MPS 上运行。

### 3.3 requires_grad

`requires_grad=True` 表示 Autograd 需要记录与该 Tensor 相关的可微运算，以便之后求梯度。输入特征通常不需要，模型参数默认需要。开启它会增加图与内存开销，不是“更精确”开关。

## 4. 形状、视图与布局

Tensor 形状规则沿用线性代数。批量全连接层通常输入 `(batch,input_features)`，输出 `(batch,output_features)`。预测形状必须在代码前写出，例如：

```text
(B,3) -> Linear(3,4) -> (B,4) -> ReLU -> (B,4)
      -> Linear(4,2) -> (B,2)
```

ReLU 逐元素，不改变形状。两类分类输出为每个样本两个 logits，不是一个已归一化概率。

### 4.1 view 与 reshape

Tensor 可能共享同一底层存储。`view` 通常要求布局兼容，`reshape` 在需要时可能创建副本。不要把两者当换轴；`permute` 或 `transpose` 改变轴顺序。操作后仍要检查轴含义，而不只检查元素总数。

### 4.2 contiguous

转置后的 Tensor 常不是连续布局，某些 `view` 会失败。调用 `.contiguous()` 可能复制成连续数据，但它不修复语义错误。先确认轴顺序是想要的，再处理布局需求。

### 4.3 squeeze 风险

批次为 1 时无参数 `squeeze()` 可能把批次轴一起删掉，使输出从 `(1,2)` 变成 `(2,)`。接口应指定只压缩哪个轴，或保持稳定批次合同。

## 5. Dataset：单个样本的协议

映射式 Dataset 最基本实现 `__len__` 和 `__getitem__`。`__getitem__(i)` 应对所有合法 i 返回相同结构、键集合、shape 和 dtype 模式。示例选择：

```python
{"features": tensor(shape=(3,), dtype=float32),
 "label": tensor(shape=(), dtype=int64)}
```

返回字典能保留名称；元组也可以，但整个数据集必须一致。不能偶数索引返回字典、奇数返回元组。单样本中的 features 没有 batch 轴，拼批后才成为 `(B,3)`。

### 5.1 初始化验证

Dataset 构造时检查：特征二维且宽度 3，标签一维且样本数一致，特征有限，标签范围合法。早失败比在第 20 个批次才出现矩阵错误更易诊断。

### 5.2 不在 __getitem__ 隐藏业务查询

每次取样实时访问数据库会导致结果随时间变化、重复查询、并发和事务不一致。教材 Dataset 使用已冻结的人工 Tensor。真实数据准备应在受控快照和权限边界内进行，记录版本与切分。

### 5.3 map-style 与 iterable-style

官方 `torch.utils.data` 支持映射式和可迭代式数据集。前者按索引访问，后者适合流式来源，但多进程分片、终止和重复问题更复杂。本章只验证映射式小数据，不从 API 存在推断已掌握流式生产加载。

## 6. DataLoader 与拼批

DataLoader 把 Dataset、采样顺序、批次大小和 collate 组合起来。默认 collate 会把相同结构的样本递归堆叠：多个 `(3,)` features 成为 `(B,3)`，多个标量标签成为 `(B,)`，字典键保持一致。

### 6.1 batch size 不总是固定

样本数不能整除批次大小时，最后批次可能更小，除非 `drop_last=True`。模型前向应使用符号 B，而不是硬编码批次为 32。指标聚合要按实际样本数加权。

### 6.2 shuffle 与随机生成器

训练常打乱，验证通常不打乱。若要复现顺序，应给 DataLoader 明确 `Generator` 并记录种子。多 worker、操作系统调度和第三方库会增加复现复杂度；本章 CPU 示例使用单进程默认 loader，只证明该局部路径。

### 6.3 自定义 collate

变长序列可能需要填充和掩码，自定义 collate 必须输出明确批次合同。不要在 collate 中静默删除非法样本，否则样本数和标签分布改变。应记录拒绝数量和原因。

## 7. nn.Module：结构与状态容器

继承 `nn.Module` 后，在 `__init__` 将子层赋给 `self`，框架才能递归注册：

```python
class TinyNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.hidden = nn.Linear(3, 4)
        self.output = nn.Linear(4, 2)

    def forward(self, x):
        return self.output(torch.relu(self.hidden(x)))
```

调用应写 `model(x)`，不要直接调用 `model.forward(x)`；`Module.__call__` 还处理钩子等框架逻辑。

### 7.1 参数注册

`nn.Linear` 内的 weight 和 bias 是 `nn.Parameter`，会出现在 `model.parameters()`、`named_parameters()` 和 `state_dict()`。把普通 Tensor 随手放进 Python 列表，框架可能无法发现；可用 `ModuleList`、`ParameterList` 等注册容器。

示例网络参数量：第一层权重 `4×3=12` 加偏置 4，共 16；第二层 `2×4=8` 加偏置 2，共 10，总计 26。运行时断言 26 是结构 oracle。

### 7.2 buffer

不训练但需随模型保存和移动的状态可注册为 buffer，例如某些归一化统计。普通属性不会自动进入 state_dict。参数、buffer 和外部配置各有职责，推理制品将在后续章节完整处理。

### 7.3 train 与 eval 不是是否求梯度

`model.train()`、`model.eval()`切换 Dropout、BatchNorm 等模块行为；它们不会自动开启或关闭 Autograd。禁用梯度要使用 `no_grad` 或 `inference_mode`。本章完整训练流程尚未开始，但必须提前建立边界。

## 8. forward 合同

一个可靠 forward 在入口明确 rank、特征宽度、dtype 和 device，在出口检查 logits 形状及有限性。是否在模块内部强制转换需要谨慎：静默 `.float()` 或 `.cpu()` 会让调用方不知道合同已被修改。

示例模块要求：

```text
input  float32 CPU (B,3)
hidden float32 CPU (B,4)
logits float32 CPU (B,2)
```

logits 是任意实数，不在 forward 内先做 argmax，也不一定先 Softmax。交叉熵通常直接接收 logits 和 int64 类别索引；过早 argmax 不可微，过早 Softmax 还可能与损失实现重复。

## 9. Autograd 动态计算图

当需要梯度的 Tensor 参与受支持运算时，PyTorch 记录操作关系。一次 forward 构建与本次实际控制流对应的图；调用标量损失的 `.backward()`，框架沿图应用链式法则，将结果累加到叶参数 `.grad`。

“动态图”意味着普通 Python 分支可以影响本次图，但也意味着图通常在反向后释放。对同一图重复 backward 往往需要显式保留，而常规做法是重新 forward 构建新图。

### 9.1 叶张量与非叶张量

用户创建并要求梯度的参数通常是叶张量，梯度存到 `.grad`。由运算产生的中间 Tensor 是非叶张量，默认不一定保留 `.grad`；它仍参与链式计算。不要看到中间 `.grad is None` 就断言反向失败。

### 9.2 标量损失

对标量调用 backward，隐式初始梯度是 1。若输出有多个元素，需要提供外部梯度或先按明确规则归约。随意 `.sum()` 会改变目标尺度；应先定义 mean 还是 sum。

### 9.3 detach 与 item

`detach()` 返回不继续记录梯度关系的 Tensor 视图语义，`.item()`把单元素 Tensor 转 Python 数。它们适合记录指标，但在损失计算中提前使用会切断图。不要用 detach 修补梯度错误而不理解路径。

## 10. 一个可手算的 Autograd oracle

令标量参数 w=3、b=1，输入 x=2，目标 t=5：

```text
y = wx+b = 3×2+1 = 7
L = (y-t)² = (7-5)² = 4
dL/dy = 2(y-t)=4
dy/dw=x=2，dy/db=1
dL/dw=4×2=8，dL/db=4
```

因此 forward 必须得到 y=7、loss=4，backward 后 w.grad=8、b.grad=4。这个 oracle 独立于神经网络随机初始化。两层示例则重点验证每个参数梯度非空、shape 与参数一致、数值有限，并在相同 CPU 环境和种子下完全重复。

### 10.1 与有限差分结合

还可对单个参数做中心差分，比较解析梯度。梯度检查通常使用 float64 和合适步长以降低数值误差，但本章资产主要验证框架图与参数注册；完整有限差分数学已在前章讲过。

## 11. 梯度会累加

PyTorch 默认把新梯度加到已有 `.grad`，以支持多次贡献累积。连续两次对同一输入重新 forward/backward而不清零，第二次 `.grad` 应为第一次两倍。这不是内存泄漏，而是定义行为；忘记清零会让优化步骤使用错误梯度。

常见模式：

```python
optimizer.zero_grad(set_to_none=True)
loss = criterion(model(x), y)
loss.backward()
optimizer.step()
```

也可 `model.zero_grad`。`set_to_none=True` 让未产生梯度与零梯度更易区分，并可能节省操作，但具体默认属于版本表面。测试应显式选择。

### 11.1 有意累积

为了模拟更大批次可以多次 backward 后再 step，但每个微批损失缩放、累积次数和何时清零必须明确。有意累积与忘记清零只有合同不同，代码表面很相似。

## 12. 原地操作与计算图

方法名以 `_` 结尾常表示原地修改，如 `add_`。Autograd 为反向可能保存前向值和版本计数；原地修改这些值会使梯度不再可靠，因此可能立即或反向时抛错。

对需要梯度的叶张量直接 `leaf.add_(1)` 会被拒绝。不要用 `with no_grad` 绕过错误后继续训练，除非该操作确实是经过设计的参数更新。优先写非原地表达式，只有理解内存、别名和梯度语义后再优化。

### 12.1 视图共享

切片、转置等可能与原 Tensor 共享存储；修改一个会影响另一个。错误可能来自远处代码。诊断时保存产生关系、是否为 view、失败操作和异常首帧，而不是只看最终 backward。

## 13. 可复现的最低合同

`torch.manual_seed(seed)` 控制一部分 PyTorch 随机数。同种子要在模型初始化前设置；DataLoader 打乱可用独立 Generator。还要记录 Python、NumPy、框架、硬件、线程、算子和数据顺序。

官方复现说明明确指出，跨版本、跨平台甚至 CPU 与 GPU 之间并不保证完全相同。本章实际证据更窄：PyTorch 2.13.0、CPU、同进程设置、固定四条数据和同种子，两次 logits 与梯度逐元素完全相同。不能推广成所有环境确定性保证。

## 14. 分阶段诊断

### 14.1 Dataset/拼批阶段

症状是 collate TypeError、键缺失、某批 shape 改变。首证据是出错样本索引、每个样本结构和 DataLoader 首个失败批。修复 Dataset 一致性，不在 collate 里静默丢样本。

### 14.2 forward 阶段

dtype、device、矩阵宽度错误通常在第一层算子失败。首证据是输入与首参数的 shape/dtype/device。修复边界转换或数据配置，不在异常后盲目 `.to()`。

### 14.3 图构建阶段

loss 不要求梯度、参数未注册或中途 detach 时，backward 可能失败或参数 grad 为 None。沿 forward 检查 `requires_grad`、`grad_fn` 和命名参数。

### 14.4 backward 阶段

原地版本冲突在 backward 日志暴露。首证据是第一条指向被修改 Tensor/操作的异常，不是最后的训练失败汇总。

### 14.5 梯度状态阶段

梯度数值恰好成倍或跨批残留，检查清零时机。先用同一批计算两次建立 oracle，再确认修复后 `.grad is None` 或归零符合选择。

## 15. FactoryCare 边界

本章四条特征和标签均为人工构造，不来自生产工单，不代表可用模型。Java 后端继续拥有设备、工单、权限、状态机和对外 API 的业务事实；Python 模型代码只能消费经授权、有版本的数据合同并产生可重建的派生结果，不能直接改写核心状态。

特征顺序、单位、时间窗口、缺失策略和标签含义必须由跨服务合同记录。Dataset 不能绕开 Java 鉴权直接抓取业务表。客户端调用 Java，Java 决定何时以及是否使用模型派生结果。模型输出不是事实，也不是自动处分人员的依据。

## 16. 可运行工件

- `examples/encyclopedia/ch.pytorch.foundations/`：稳定 Dataset、批次、两层 Module、一次 forward/backward和同种子 CPU 复跑。
- `labs/encyclopedia/ch.pytorch.foundations/`：返回结构、dtype、声明设备、原地操作与梯度累积故障。
- `exercises/encyclopedia/ch.pytorch.foundations/`：输出层故意只有一个 logit，初始稳定红灯。
- `solutions-private/encyclopedia/ch.pytorch.foundations/`：两类输出与有限梯度答案。

正确示例、实验和私有答案应绿；公开练习修复前应红。所有入口允许 `PYTHON_BIN` 指定隔离解释器，且不把未安装依赖当通过。

## 17. 120 秒复述模板

“Tensor 同时有数值、shape、dtype 和 device；Dataset 定义单样本稳定结构，DataLoader按批拼接；Module 注册子层、参数和状态并提供 forward 合同；Autograd 根据实际张量运算建立图，backward 后把梯度累加到叶参数。关键证据是每层形状、批次返回模式、命名参数、有限且同形梯度，以及固定 CPU 环境同种子复跑。越界反例是脚本在 CPU 玩具数据能反向，就宣称 GPU/MPS 可用或模型有生产质量。本章只验证框架基础，不完成训练、评估或部署。”

## 18. 自测题

1. `(B,3)` 经过 `Linear(3,4)` 和 `Linear(4,2)` 后各是什么形状？
2. 类别标签给交叉熵时为什么常用 int64？
3. Dataset 单样本 `(3,)` 怎样变成批次 `(B,3)`？
4. `model.eval()` 是否关闭梯度？
5. 为什么应调用 `model(x)` 而不是直接 `forward`？
6. 中间非叶 Tensor 的 grad 为 None 是否必定出错？
7. 两次 backward 不清零为何得到两倍梯度？
8. 原地操作为什么可能破坏反向？
9. 同种子同 CPU 一次复现能否证明跨版本完全一致？
10. Python 模型结果为什么不能直接成为工单状态？

## 19. 答案要点

1. `(B,4)`、`(B,2)`。
2. 该损失的类别索引合同通常要求长整型，浮点标签表示另一种目标语义。
3. 默认 collate 在新批次轴堆叠相同结构样本。
4. 不能；它切换模块行为，禁用梯度需 no_grad/inference_mode。
5. `__call__`还执行框架钩子等逻辑。
6. 不必；非叶默认不保留 `.grad`，但仍参与链式反向。
7. PyTorch 默认累加梯度，支持多来源贡献。
8. 反向保存的前向值或版本被修改，梯度公式失去所需输入。
9. 不能；官方也不保证跨版本/平台完全复现。
10. Java 拥有业务事实和授权，模型只提供不确定、可重建的派生证据。

## 20. 官方资料

- [PyTorch 当前安装入口](https://pytorch.org/get-started/locally/)：平台、Python 与计算后端选择；同日页面版本文字存在不同步，故注册表保持 provisional。
- [PyTorch 2.13 Tensor 参考](https://docs.pytorch.org/docs/2.13/tensors.html)：Tensor 属性与操作。
- [torch.utils.data 参考](https://docs.pytorch.org/docs/2.13/data.html)：Dataset、DataLoader 与拼批。
- [nn.Module 参考](https://docs.pytorch.org/docs/2.13/generated/torch.nn.Module.html)：模块、参数与调用合同。
- [Autograd 参考](https://docs.pytorch.org/docs/2.13/autograd.html)与[机制说明](https://docs.pytorch.org/docs/2.13/notes/autograd.html)：计算图和梯度规则。
- [复现说明](https://docs.pytorch.org/docs/2.13/notes/randomness.html)：跨版本与平台的限制。

资料核对日期为 2026-07-24。版本链接用于界定当前表面；数学与数据合同仍需由本地 oracle 独立验证。
