# PyTorch：张量、模型、训练与推理

## 1. PyTorch 把张量计算、自动求导和模型训练连在一起

典型流程：

```text
Dataset / DataLoader 提供批次
  → nn.Module 前向计算
  → loss 衡量误差
  → autograd 计算梯度
  → optimizer 更新参数
  → 验证、保存、加载和推理
```

框架减少求导和设备计算样板，但数据合同、评估和业务边界仍由开发者负责。

## 2. 先记录运行环境，再讨论复现

至少记录 Python、PyTorch、CUDA/加速后端、驱动、设备、依赖锁、代码提交和配置。`torch.__version__` 相同也不保证所有硬件和算子结果逐位一致。

模型行为问题先区分代码、数据、随机性、设备和版本差异。

## 3. Tensor 同时有 shape、dtype 和 device

```python
import torch

x = torch.tensor([[1.0, 2.0], [3.0, 4.0]])
print(x.shape, x.dtype, x.device)
```

同样数字若 dtype 或 device 不同，精度、性能和可执行操作都会不同。进入模型前应检查三者。

## 4. 数据和模型必须位于兼容设备

CPU tensor 不能直接与 GPU/MPS 参数做运算。常见模式是确定一个设备，再统一移动模型和每个批次：

```python
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = model.to(device)
inputs = inputs.to(device)
```

可用设备取决于实际构建和系统，不能只根据机器型号猜。

## 5. dtype 是精度、范围和性能合同

索引和分类标签常用整数类型，模型参数常用浮点类型。混合精度能提高吞吐并降低显存，但会引入缩放和数值稳定问题。

先用清晰稳定的精度验证正确性，再按硬件和指标测量优化。

## 6. `requires_grad` 表示是否追踪梯度

模型参数通常自动注册并需要梯度。普通输入默认不需要，除非任务要计算输入梯度。

```python
w = torch.tensor(2.0, requires_grad=True)
loss = (w - 5) ** 2
loss.backward()
print(w.grad)
```

反向后梯度保存在叶子张量的 `.grad` 中。

## 7. view、reshape 和 contiguous 涉及内存布局

切片和换轴可能产生非连续张量。`view` 对布局有要求，`reshape` 会尽量返回视图，必要时复制。

不要把 reshape 当成换轴；轴顺序改变应使用 transpose/permute，再检查输出 shape 和语义。

## 8. `squeeze` 可能误删批次维

无参数 `squeeze()` 会删除所有长度为 1 的轴。当 batch size 恰好为 1 时，可能把批次轴也删掉，使代码只在某些批次失败。

明确指定要删除的维度，并测试空批次、单样本和最后一个不满批次。

## 9. Dataset 定义如何取得一个样本

Map-style Dataset 通常实现长度与按索引取样：

```python
class WorkOrderDataset(torch.utils.data.Dataset):
    def __len__(self):
        return len(self.rows)

    def __getitem__(self, index):
        return self.features[index], self.labels[index]
```

初始化时验证 Schema，`__getitem__` 应确定且快速，不要隐藏数据库远程查询。

## 10. IterableDataset 适合流式或无法随机访问的数据

日志流、大文件和生成式数据可能只能顺序读取。多 worker 时必须明确如何分片，否则每个 worker 可能重复整份数据。

无法精确知道长度会影响 epoch、进度条和指标分母，需要显式定义训练步数。

## 11. DataLoader 负责拼批和加载策略

```python
loader = DataLoader(
    dataset,
    batch_size=32,
    shuffle=True,
)
```

训练常打乱，验证和推理通常保持确定顺序。最后批次可能小于 batch size，模型不能假设永远是 32。

worker 数越多不一定越快，受磁盘、CPU、序列化和内存限制。

## 12. `collate_fn` 定义多个样本如何组成批次

固定形状 tensor 可使用默认拼批。变长文本、图结构和带缺失字段的样本可能需要 padding、mask 或自定义容器。

collate 后应明确每个字段 shape、dtype、mask 方向和排序关系。

## 13. `nn.Module` 是结构与状态的容器

```python
from torch import nn

class DurationModel(nn.Module):
    def __init__(self, input_size: int) -> None:
        super().__init__()
        self.network = nn.Sequential(
            nn.Linear(input_size, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
        )

    def forward(self, x):
        return self.network(x)
```

把子模块赋给属性后，PyTorch 会注册其参数。

## 14. 普通 Tensor 不会自动成为参数

需要训练的自定义张量应使用 `nn.Parameter`；需要保存但不训练的持久状态，如某些统计量，可注册为 buffer。

未注册的 tensor 不会自动进入 `parameters()`、设备迁移或 `state_dict`，容易形成静默错误。

## 15. `forward` 应有清晰输入输出合同

写清：输入键、shape、dtype、device、值范围、mask 和输出含义。不要让 forward 随机读文件、查询数据库或依赖全局配置。

业务后处理和阈值决策通常放在模型外，使训练张量计算与产品政策分开。

## 16. Autograd 在前向时构建动态计算图

对需要梯度的 tensor 执行运算时，PyTorch 记录运算关系。调用 `backward()` 后按图反向应用链式法则。

图通常在反向后释放。随意保留带图 tensor 或把每轮 loss 直接放入列表，可能持续占用内存。

## 17. 标量损失最适合直接 `backward`

批次损失常先归约为一个标量：

```python
prediction = model(inputs)
loss = loss_fn(prediction, targets)
loss.backward()
```

如果输出不是标量，需要提供上游梯度或先明确归约。sum 与 mean 会影响梯度尺度。

## 18. 梯度默认累加

多次 `backward()` 会把新梯度加到现有 `.grad`。标准训练步通常先清零：

```python
optimizer.zero_grad(set_to_none=True)
loss.backward()
optimizer.step()
```

有意做梯度累积时，要按微批次数和损失归约正确缩放，并记录何时真正 step。

## 19. 原地操作可能破坏反向所需的值

带下划线的方法常表示原地修改，如 `add_`。若 autograd 还需要旧值计算梯度，PyTorch 可能报版本错误；更危险的是在不受保护处静默改了共享 view。

训练核心逻辑优先使用非原地表达，只有测量证明必要并理解图依赖后再优化。

## 20. `detach()` 和 `item()` 会离开计算图

`tensor.detach()` 返回不再追踪梯度的视图语义 tensor；`tensor.item()` 把单元素 tensor 转成 Python 数值。

它们适合日志和指标，但放错位置会切断模型梯度。不要用 detach 消除梯度错误而不理解原因。

## 21. 一轮标准训练有固定顺序

```python
model.train()
for inputs, targets in train_loader:
    optimizer.zero_grad(set_to_none=True)
    predictions = model(inputs)
    loss = loss_fn(predictions, targets)
    loss.backward()
    optimizer.step()
```

实际实现还应检查非有限 loss/gradient、记录分子分母、处理设备和取消，并给日志关联运行 ID。

## 22. `model.train()` 只切换层模式

它让 Dropout、BatchNorm 等进入训练行为，不会自动启用优化器或反向传播。`model.eval()` 切换推理行为，也不会自动关闭梯度。

这两个概念要分开记：层的行为模式，以及 autograd 是否记录计算。

## 23. 验证阶段不更新参数

```python
model.eval()
with torch.inference_mode():
    for inputs, targets in validation_loader:
        predictions = model(inputs)
        ...
```

验证使用固定模型，只聚合损失和业务指标。不要调用 backward/step，也不要在验证数据上重新拟合预处理。

## 24. 指标聚合要按样本量加权

若每个批次 loss 是均值，不能简单把各批次均值再平均，因为最后批次可能更小。累加 `batch_loss × batch_size` 和样本总数，再相除。

分类指标也应累加混淆矩阵的计数，而非随意平均批次 precision。

## 25. 训练、验证和测试应保持严格职责

训练数据更新参数；验证数据选择 epoch、超参数和阈值；测试数据只评估冻结方案。最佳检查点通常按预先选择的验证指标保存。

不要展示测试曲线并据此决定训练多久，这已经把测试集用于调参。

## 26. 早停应恢复最佳检查点

当验证指标若干轮没有改善时停止，最终使用最佳轮的参数，而非停止时最后一轮。耐心值、改善方向和最小改善量要在实验配置中记录。

验证噪声较大时，一次小幅变化不一定有意义。

## 27. 可复现需要固定更多条件

随机种子、数据划分、DataLoader 生成器、初始化、依赖、代码和硬件都影响结果。某些加速算子本身可能非确定。

报告应区分：同机同环境可复现、同版本跨设备近似复现、跨版本只保证指标范围。不要承诺无法验证的逐位一致。

## 28. 检查点不只是模型权重

用于续训的检查点通常包含：

```text
model state_dict
optimizer state_dict
scheduler / scaler 状态
epoch 和 global step
最佳指标
模型与特征配置
随机状态（需要严格续训时）
```

写文件应尽量原子化，并在新进程实际加载验证。

## 29. `state_dict` 是推荐的状态表示

保存整个 Python Module 对象会绑定源码路径和 pickle 行为，也带来不可信反序列化风险。更常见做法是：根据受控配置构造模型，再加载 `state_dict`。

加载来源必须可信。`weights_only` 等加载安全行为会随 PyTorch 版本变化，按当前官方文档核对，不能把任意外部模型文件当安全数据。

## 30. 推理制品需要权重之外的完整合同

```text
模型结构与版本
权重
输入 Schema 和字段顺序
预处理参数
标签映射
阈值与后处理
依赖/运行时要求
黄金输入输出样本
完整性哈希和来源
```

只有 `.pt` 权重往往无法重现训练时的真实预测。

## 31. 加载时先构造兼容结构，再恢复权重

```python
model = DurationModel(input_size=config.input_size)
state = torch.load(path, map_location=device, weights_only=True)
model.load_state_dict(state)
model.to(device)
model.eval()
```

具体参数以锁定版本为准。未知配置、缺失键、意外键和 shape 不符应 fail closed，而不是尽量忽略后继续服务。

## 32. `map_location` 处理保存设备与加载设备差异

GPU 保存的权重可能需要在 CPU 服务或另一设备加载。显式指定加载位置能避免设备不可用错误和不必要显存占用。

加载后还要把实际输入移动到同一设备。

## 33. `inference_mode` 用于纯推理

它关闭梯度记录并减少部分开销，通常比只用 `no_grad` 更严格。若后续代码需要 autograd 相关行为，应选择合适作用域。

无论使用哪种方式，都要同时 `model.eval()`，因为关闭梯度不会自动切换 Dropout/BatchNorm。

## 34. 单条输入也按批次合同处理

若模型输入是 `(batch, features)`，单条请求应形成 `(1, features)`，不要随意 squeeze 成 `(features,)`。

空批次、超大批次、缺字段、非有限值和错误 dtype 应在模型调用前拒绝，并返回稳定错误。

## 35. 批量推理需要保持请求与结果对应

动态批处理把短时间到达的请求合并，提高吞吐，但会增加排队延迟。必须保存每条请求的位置、取消状态和模型版本，再把结果准确拆回。

一个坏输入是否让全批失败，要由合同决定；不能把不同租户敏感数据混进可泄露的日志或缓存。

## 36. 延迟、吞吐和资源要一起测

- 延迟：单个请求等待多久，通常看 p50/p95/p99。
- 吞吐：单位时间处理多少样本。
- 资源：CPU/GPU、显存、内存和功耗。

测量需要预热、固定输入 shape、明确批次与设备，并把数据加载和预处理是否包含在内写清。

## 37. 模型服务必须有容量和降级

限制请求大小、并发、批次和队列长度。过载时应明确拒绝或降级到规则/人工流程，不能无限等待。

客户端取消不一定能中止 GPU 已提交计算，但至少可以停止后续工作并不再交付过期结果。

## 38. 模型版本应进入响应和日志

每次预测至少能追溯到模型制品 ID、特征版本、阈值版本和请求关联 ID。否则指标变坏时无法判断是哪一版造成。

日志记录元数据和安全摘要，不记录完整敏感特征。

## 39. 发布与回滚都要做新进程加载验证

制品晋级不是复制文件名。发布前在干净环境加载、运行黄金样本、检查 Schema/哈希、做性能烟雾验证。回滚前同样确认旧模型仍兼容当前服务和特征管线。

数据库或特征合同若已破坏兼容，单纯换回旧权重也无法回滚。

## 40. PyTorch 调试的证据顺序

```text
Dataset 单样本
  → DataLoader 单批 shape/dtype
  → forward 输出与 loss
  → backward 后每层梯度
  → optimizer.step 后参数确实变化
  → 小批次可过拟合
  → 验证循环无更新
  → 新进程保存加载结果一致
```

把问题缩到最小阶段，比一边完整训练一边盲目改超参数有效得多。

## 41. 这一阶段应形成的整体地图

```text
Tensor（shape/dtype/device）
  → Dataset 单样本
  → DataLoader 拼批
  → Module.forward
  → loss.backward
  → optimizer.step
  → validation / checkpoint
  → 完整推理制品
  → 受限容量的模型服务
```

必须掌握：Tensor 有形状、类型和设备；Module 只自动管理已注册参数/缓冲；梯度默认累加；train/eval 不控制 autograd；验证不更新参数；检查点与推理制品用途不同；权重不等于完整模型；不可信模型文件有加载风险；上线预测必须可追溯并能降级。

PyTorch 的保存加载、安全默认、编译和设备支持会变化，实施时以项目锁定版本的官方教程与 API 文档为准。
