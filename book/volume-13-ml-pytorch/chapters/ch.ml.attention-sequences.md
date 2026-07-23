---
schema_version: 2
edition: 2026.2-draft
id: ch.ml.attention-sequences
title: Softmax、序列表示、注意力与 Transformer 桥接
responsibility: 用序列位置、Softmax 和 Q/K/V 矩阵解释自注意力与 Transformer 数据流，只建立模型心智桥，不训练大模型。
volume: '13'
order: 12
level: L2+
status: drafting
path: book/volume-13-ml-pytorch/chapters/ch.ml.attention-sequences.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ml.neural-networks
version_surfaces:
- python-3.14
- numpy
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Softmax、序列表示、注意力与 Transformer 桥接”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ml-sequence-attention
  - ml-transformer-bridge
  covers_topics:
  - ml.sequence-representation
  - ml.softmax
  - ml.query-key-value
  - ml.scaled-dot-product-attention
  - ml.positional-information
  - ml.multihead-intuition
  - ml.residual-normalization
  - ml.transformer-block-flow
  uses_capabilities:
  - math.algebra-functions
  - math.linear-calculus
  - math.probability-statistics
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Softmax、序列表示、注意力与 Transformer 桥接”构建可运行程序与测试：对三个 token 手算 Q/K/V、缩放分数、Softmax 权重和加权输出，并绘制残差块数据流与形状；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ml-sequence-attention
  - ml-transformer-bridge
  covers_topics:
  - ml.sequence-representation
  - ml.softmax
  - ml.query-key-value
  - ml.scaled-dot-product-attention
  - ml.positional-information
  - ml.multihead-intuition
  - ml.residual-normalization
  - ml.transformer-block-flow
  uses_capabilities:
  - math.algebra-functions
  - math.linear-calculus
  - math.probability-statistics
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: matrix-hand-check-softmax-sum-check-shape-trace
- id: diagnose
  kind: fault-diagnosis
  text: 面对“Softmax 轴选错、缩放因子遗漏、序列/特征轴交换或把注意力权重当因果解释”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ml-sequence-attention
  - ml-transformer-bridge
  covers_topics:
  - ml.sequence-representation
  - ml.softmax
  - ml.query-key-value
  - ml.scaled-dot-product-attention
  - ml.positional-information
  - ml.multihead-intuition
  - ml.residual-normalization
  - ml.transformer-block-flow
  uses_capabilities:
  - math.algebra-functions
  - math.linear-calculus
  - math.probability-statistics
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Softmax、序列表示、注意力与 Transformer 桥接

> 注意力可以被拆成几次线性投影、相似度计算、Softmax 和加权求和。Transformer 则把注意力、前馈网络、残差和归一化组织成可重复的块。本章只建立能逐矩阵验证的桥梁，不训练大模型，不把注意力权重冒充因果解释，也不把框架的高性能内核当作数学定义。

## 1. 为什么普通固定向量不够

很多输入天然有顺序：句子由 token 构成，传感器记录由时间点构成，维修记录由事件构成。若把整个序列直接求和，`A 后 B` 与 `B 后 A` 可能得到相同结果；若固定只看最后一个元素，又会丢失更早的信息。

序列模型需要同时回答：

- 每个位置是什么内容；
- 它位于哪里；
- 当前位置应从哪些位置聚合信息；
- 哪些位置因填充、未来信息或权限而不可见；
- 输出的形状如何继续流向后续层。

自注意力让序列中的每个位置根据当前内容，计算对所有可见位置的权重并聚合值。它不自动理解语义；语义来自训练数据、目标和学得的参数。

## 2. token、词表与表示向量

“token”是模型处理的离散单位，可以是字、子词、事件代码或离散状态。分词器把原始输入变成 token ID；嵌入表再把每个 ID 映射到 `D_model` 维向量。

对批次序列，常见形状：

```text
token_ids: (B, S)
X:         (B, S, D_model)
```

`B` 是批次，`S` 是序列长度，`D_model` 是每个位置的特征维度。不同 API 也可能使用 `(S,B,D)`；不能凭经验猜轴，必须读合同并写形状账本。

嵌入向量不是词典定义，也不是用户可直接解释的字段。它只是训练得到的坐标。两个向量相近可能反映某种统计相似，但不能直接推出因果、价值判断或业务等价。

## 3. 顺序信息必须显式进入

没有位置信息时，自注意力对输入排列具有置换等变性：同时重排输入位置，输出也按相同方式重排，却不知道“第一个”和“最后一个”的特殊意义。

常见位置机制包括：

- 固定正弦/余弦位置编码；
- 可学习绝对位置嵌入；
- 相对位置偏置；
- 旋转位置表示等现代变体。

稳定原理是“内容之外还需表达位置关系”；具体 API、最大长度、插值方式和外推能力是版本与模型合同。把位置向量加到 token 向量时，二者形状都应是 `(S,D_model)` 或可安全广播的等价形式。

位置编号不是时间本身。事件间隔不等时，只加序号可能掩盖真实时差；应把时间间隔、时间戳派生特征或专门时间编码作为明确输入，并防止未来字段泄漏。

## 4. Softmax：把一行分数变成权重

给定向量 `z`：

\[
\operatorname{softmax}(z_i)=\frac{e^{z_i}}{\sum_j e^{z_j}}
\]

输出每项为正，整行和为 `1`。Softmax 保留分数排序，却不是线性归一化；分数差值决定尖锐程度。给所有分数加同一常数，结果不变。

### 4.1 数值稳定实现

直接算 `exp(1000)` 会溢出。利用平移不变性：

```python
shifted = scores - scores.max(axis=-1, keepdims=True)
weights = np.exp(shifted)
weights /= weights.sum(axis=-1, keepdims=True)
```

`keepdims=True` 保留归约轴，避免错误广播。减最大值没有改变数学结果，却显著提高数值稳定性。

### 4.2 轴是合同的一部分

注意力分数形状通常是 `(..., S_query, S_key)`。每个 query 都要在所有 key 上分配权重，因此 Softmax 应沿最后的 key 轴。若沿 query 轴归一化，某些矩阵的列和会等于一，看起来“也归一化了”，但语义已经错误。

最小 oracle：`weights.sum(axis=-1)` 必须逐 query 接近全一；同时用非对称数据检查，避免对称矩阵让错误轴侥幸通过。

### 4.3 温度与尺度

`softmax(z/T)` 中，较小 `T` 更尖锐，较大 `T` 更平缓。注意力的 `sqrt(d_k)` 缩放有类似控制作用，但来源是点积方差随维度增长。不要把温度校准、采样温度和注意力缩放混成同一业务概念。

## 5. Query、Key、Value 的角色

输入表示 `X` 经三组参数投影：

\[
Q=XW_Q,\quad K=XW_K,\quad V=XW_V
\]

- Query：当前位置“要找什么”；
- Key：每个候选位置“可用什么来匹配”；
- Value：匹配后真正被聚合的内容。

这是计算角色类比，不是数据库查询、主键和值对象。`Q` 与 `K` 的最后维度要可做点积，`V` 的最后维度可以不同。

无批次单头形状账本：

```text
X:       (S, D_model)
W_Q:     (D_model, D_k)    -> Q: (S, D_k)
W_K:     (D_model, D_k)    -> K: (S, D_k)
W_V:     (D_model, D_v)    -> V: (S, D_v)
Q @ K.T: (S, S)
weights: (S, S)
output:  (S, D_v)
```

每行输出对应一个 query；每列权重对应一个 key/value 位置。

## 6. 缩放点积注意力

核心公式：

\[
\operatorname{Attention}(Q,K,V)=
\operatorname{softmax}\left(\frac{QK^T}{\sqrt{d_k}}+M\right)V
\]

`M` 是可选 mask：允许位置加 `0`，禁止位置在 Softmax 前加足够负的值或 `-inf`。步骤不可颠倒：先算分数、缩放、加 mask，再沿 key 轴 Softmax，最后乘 `V`。

若 `Q/K` 各维近似独立且方差类似，点积方差会随 `d_k` 增长。除以 `sqrt(d_k)` 可避免 Softmax 过早饱和、梯度过小。这是统计尺度控制，不是为了让权重和为一；Softmax 无论是否缩放都会归一化。

## 7. 三个 token 的完整手算

为让缩放后的分数是简单整数，取 `D_model=D_k=4`、`D_v=2`：

```text
X = Q = K =
[[1, 1, 0, 0],
 [0, 0, 1, 1],
 [1, 1, 1, 1]]                 shape (3, 4)

W_Q = W_K = I4                 shape (4, 4)
W_V =
[[0.5, 0.0],
 [0.5, 0.0],
 [0.0, 0.5],
 [0.0, 0.5]]                  shape (4, 2)

V = X @ W_V =
[[1, 0],
 [0, 1],
 [1, 1]]                      shape (3, 2)
```

`sqrt(d_k)=2`。点积与缩放分数：

```text
Q @ K.T = [[2, 0, 2],
           [0, 2, 2],
           [2, 2, 4]]

scores = [[1, 0, 1],
          [0, 1, 1],
          [1, 1, 2]]
```

逐行 Softmax。设 `e≈2.7182818`：

```text
softmax([1,0,1])
= [e/(2e+1), 1/(2e+1), e/(2e+1)]
≈ [0.422319, 0.155362, 0.422319]

softmax([0,1,1])
≈ [0.155362, 0.422319, 0.422319]

softmax([1,1,2])
≈ [0.211942, 0.211942, 0.576117]
```

每行和为 `1`。乘 `V`：

```text
O ≈ [[0.844638, 0.577681],
     [0.577681, 0.844638],
     [0.788058, 0.788058]]     shape (3, 2)
```

第一行第一维等于第一个和第三个 value 的权重之和；第二维等于第二和第三个权重之和。这种逐元素解释是强 oracle，比只断言最终 shape 更可信。

若遗漏缩放，分数变为 `[2,0,2]` 等，Softmax 更尖锐，结果不同；但每行仍和为一。因此测试必须同时比较已知分数/输出，不能只检查行和。

## 8. mask：不可见位置必须在 Softmax 前排除

### 8.1 padding mask

不同样本补齐到相同长度时，padding 不是内容。对应 key 位置必须屏蔽，否则有效 token 会把权重分给填充值。只在最终输出乘零不等价，因为 padding 已影响归一化分母。

### 8.2 causal mask

自回归生成中，位置 `i` 不能读取未来 `j>i`。上三角未来分数在 Softmax 前设为 `-inf`。这防止训练时从目标后文偷看，也是数据泄漏边界。

### 8.3 全遮蔽行

若某个 query 的所有 key 都被遮蔽，Softmax 可能产生 `nan`。合同必须决定：禁止这种输入、保留专门可见 token，或显式处理全遮蔽情况。不能等线上出现 `nan` 才猜测。

布尔 mask 在不同 API 中可能表示“True=允许”或“True=禁止”；这是版本/API 面，必须看当前文档和测试，不能凭记忆互换。

### 8.4 mask 广播既是形状问题也是数据边界

批次多头分数常为 `(B,H,S_q,S_k)`，而 padding mask 可能从 `(B,S_k)` 扩展。正确广播通常要显式增加 head 和 query 轴。若误把批次轴对齐到 head 轴，某些 `B==H` 的测试会静默通过，却把一个样本的可见性应用到另一个样本。

测试不能只用 `B=H=1`。至少构造两个样本、两个不同 padding 模式，并断言每个样本的禁止位置权重恰为零。涉及租户或权限的数据绝不能只依赖注意力 mask 隔离；访问控制必须在 Java/数据服务边界先完成。模型 mask 是计算可见性，不是安全授权机制。

浮点 mask 还有 dtype 边界：在 float32 中常见巨大负值，在 float16 中某些常量可能直接成为负无穷或产生不同数值行为。数学合同是禁止项在归一化后权重为零；具体常量应通过当前 dtype/API 测试。

### 8.5 Softmax 熵只能描述集中程度

权重分布的熵 `H=-sum(p_i log p_i)` 可以描述一行较均匀还是较集中。熵低不等于模型更确定、更正确或更可解释；它只说明这组内部权重集中。mask 后可见位置数不同，最大可能熵也不同，直接比较不同长度序列会误导。

当分数差过大，Softmax 接近 one-hot，非最大位置梯度可能很小；差值都接近零时权重近似均匀。缩放、初始化和归一化帮助控制此行为，但训练仍可能有意学到集中或分散模式。不能规定“注意力必须平均”作为普遍质量标准。

## 9. 自注意力与交叉注意力

自注意力的 `Q/K/V` 来自同一序列表示，输出仍按该序列的 query 位置排列。交叉注意力中，`Q` 来自一个序列，`K/V` 来自另一个来源，例如解码器查询编码器输出。

形状因此可能是：

```text
Q: (S_q, D_k)
K: (S_k, D_k)
V: (S_k, D_v)
weights: (S_q, S_k)
output: (S_q, D_v)
```

不要默认分数矩阵总是方阵。自注意力常为 `S×S`，交叉注意力可以是 `S_q×S_k`。

## 10. 多头注意力的直觉与形状

单头使用一组 `W_Q/W_K/W_V`。多头把模型维度投影成 `H` 组较小子空间，各头独立计算注意力，再拼接并做输出投影：

```text
X:             (B, S, D_model)
Q/K:           (B, H, S, D_k)
scores:        (B, H, S, S)
V:             (B, H, S, D_v)
head outputs:  (B, H, S, D_v)
concat:        (B, S, H*D_v)
projection:    (B, S, D_model)
```

“不同头学习不同关系”是一种可能而非保证。多个头可能冗余，也不能给每个头强行贴上人类语义标签。头数必须整除相关维度只是常见实现合同，不是所有变体的宇宙定律。

批次、头、query、key、特征五类轴很容易交换。用命名说明和小非对称数据验证，比在代码里连续 `reshape/transpose` 后只看最终形状更可靠。

### 10.1 注意力 dropout 的位置

一些实现会在 Softmax 权重上应用 dropout，再聚合 `V`；训练时它随机丢弃部分连接并对保留项缩放。此时单次训练前向的权重行和未必仍严格等于一，所以“行和为一”oracle 应用于 dropout 前的概率，或在评估模式把 dropout 关闭。

训练/评估模式切换是 API 合同，不是数学公式自动完成。PyTorch 当前 SDPA 文档特别提醒该函数会按传入的 `dropout_p` 应用 dropout，调用者在评估时应显式传 `0.0`。本章 NumPy oracle 没有 dropout，因而保持确定性行和检查；它不能证明含随机正则化的训练路径正确。

## 11. 残差连接为什么重要

残差形式：

\[
Y=X+F(X)
\]

它提供一条恒等路径，让层可以学习对输入的修正，并改善深层梯度传播。相加要求形状一致，因此多头拼接后通常通过输出投影回到 `D_model`。

残差不是简单“把旧信息保留一份”的业务缓存，也不保证没有信息损失。它是网络计算图的一条路径。若 `F(X)` 尺度失控，残差仍可能数值不稳。

## 12. Layer Normalization

LayerNorm 通常对每个 token 的特征维归一化：减去该位置特征均值，再除以标准差，并带可学习缩放和平移。它与按批次统计的 BatchNorm 不同，更适合变长序列和小批次。

Transformer 存在 pre-norm 与 post-norm 等组织：

```text
pre-norm:  X -> LN -> Attention -> +X
post-norm: X -> Attention -> +X -> LN
```

二者训练行为不同。稳定心智模型是“归一化、子层、残差有明确顺序与形状”；具体架构必须读模型配置，不应只说“Transformer 都一样”。

## 13. 位置前馈网络

注意力之后通常还有对每个位置独立应用的前馈网络：

\[
\operatorname{FFN}(x)=W_2\phi(W_1x+b_1)+b_2
\]

它在位置间不混合，位置交互已由注意力完成；但它在特征维上做非线性变换。权重对所有位置共享。完整块常包含：

1. 归一化；
2. 多头注意力；
3. 残差；
4. 归一化；
5. 前馈网络；
6. 残差。

dropout、门控 FFN、位置方案和顺序存在多种变体。本章要求能画数据流和形状，不要求复现任一大型模型。

## 14. 编码器、解码器与 Transformer 桥

编码器块常使用双向自注意力，让每个位置读取整个有效输入。自回归解码器使用 causal 自注意力，只读取当前位置及过去。编码器—解码器模型还可能加入交叉注意力。

训练大语言模型还涉及分词、海量语料、目标构造、并行、优化、对齐、安全和推理系统。理解三 token 注意力只说明你能解释核心数据流，绝不意味着已经会训练或部署大模型。

### 14.1 反向传播怎样穿过注意力

输出 `O=AV` 中，损失既对 `V` 有梯度，也对权重 `A` 有梯度；`A` 又通过 Softmax 依赖缩放分数，分数依赖 `Q` 与 `K`。因此 `W_Q/W_K/W_V` 都能从同一损失获得梯度。若某条路径被 mask，禁止位置的权重为零，其分数梯度也应符合 mask 合同。

Softmax 的每个输出依赖同一行所有输入，所以其雅可比不是逐元素独立导数。框架自动求导会组织这些乘积；手写时不能把 Softmax 当 Sigmoid 对每格单独求导。后续学习 PyTorch 时，应先用 NumPy 前向 oracle 对齐，再用小矩阵梯度检查或 Autograd 对照，而不是一上来调大型模型。

残差连接为梯度提供绕过子层的恒等路径，但并不会阻止所有消失/爆炸。归一化位置、深度、初始化和优化器仍影响训练。这里的形状图只证明张量能相加，不证明训练稳定。

### 14.2 测试注意力需要分层 oracle

可靠测试不只断言最终输出，而应分别检查：投影 `Q/K/V`、转置和缩放后的分数、mask 后禁止权重、逐 query 行和、加权输出以及全程形状。还要把“权重不是因果证据”写入报告边界。

对称输入会让转置、错误轴或头交换侥幸不变。fixture 应故意非对称，并包含不同 mask、`S_q!=S_k` 或 `B!=H` 的边界。只用随机数组可能发现失败却不易人工判断正确值；小手算 fixture 与随机性质测试应互补。

## 15. 注意力复杂度与长序列边界

标准自注意力分数矩阵为 `S×S`，时间和显存通常随序列长度平方增长。多头、批次和 dtype 进一步影响成本。长上下文方案可能采用稀疏、分块、滑窗、低秩或专用内核，但这些改变了可见范围、近似或硬件路径，需要单独证据。

不能仅由公式推断某个 GPU 的真实吞吐，也不能由高性能内核名称推断确定性。PyTorch 的 scaled dot-product attention 可在运行时选择不同后端；官方复现文档明确区分不同后端的确定性特征。本章 NumPy 小矩阵没有验证任何 GPU 路径。

## 16. 注意力权重不是因果解释

权重说明在特定模型、特定层头和特定输入下，value 如何被加权进入某个中间输出。它不自动回答：

- 改变该 token 是否必然改变最终决策；
- 该 token 是否是现实世界原因；
- 模型是否通过其他层和残差使用同一信息；
- 数据中的相关关系是否公平或合法。

把热力图称为“模型因果解释”是越界。若要研究贡献，可结合扰动、消融、梯度方法、反事实和领域评审，而且每种方法都有假设。解释工具结果本身也需验证。

## 17. 常见失败与第一可信证据

### 17.1 Softmax 轴选错

表现：程序运行、矩阵尺寸正常，但每个 query 的行和不为一。第一证据是 `weights.sum(axis=-1)` 与形状账本。使用非对称矩阵避免错误轴也碰巧通过。

### 17.2 遗漏 `sqrt(d_k)`

表现：行和仍为一，但权重比手算更尖锐。第一证据是 Softmax 前的 score 数值。检查 `d_k` 是 query/key 的每头特征维，不是序列长度或模型总维。

### 17.3 序列轴与特征轴交换

表现：矩阵乘法报错，或某些方阵尺寸下静默执行。第一证据是 `Q,K,V,scores` 逐步形状。不要用大量转置把错误“试到能跑”。

### 17.4 mask 方向反了

表现：有效位置被遮蔽、未来泄漏或出现全行 `nan`。第一证据是 mask 可视化和 Softmax 前分数；用明确小例验证允许/禁止语义。

### 17.5 把权重当因果解释

这不是数值异常，而是结论越界。第一证据是报告措辞与实际测量：实验只得到内部聚合系数，没有干预测试或因果识别设计。修复应降低结论强度并补充必要评估。

## 18. FactoryCare 的序列与模型边界

维修历史可以表示为事件序列，但要先定义样本时点：预测时只能使用当时已经发生且可获得的事件。把工单最终处理结果、未来告警或事后备注放入输入，会造成时间穿越泄漏。

合理边界：

```text
Java 持有事件事实、租户和权限
  -> 按预测时点形成版本化只读特征
Python 产生风险/优先级建议及模型版本
  -> Java 执行业务规则、人工确认和最终写入
```

Python 不拥有工单状态机，注意力模型也不能绕过 Java 权限读取其他租户历史。序列截断、缺失、超长、未知 token 和服务失败都需要回退合同。注意力热力图若展示给用户，必须明确它不是因果原因。

## 19. 实验与验收顺序

1. 写出三 token 的 `X,WQ,WK,WV` 与全部形状；
2. 手算 `Q,K,V`；
3. 手算未缩放点积和除以 `sqrt(d_k)` 的分数；
4. 用减最大值的 Softmax 逐行求权重；
5. 检查每行和为一；
6. 手算 `weights @ V`；
7. 用独立 NumPy 程序比较所有中间矩阵；
8. 绘制“位置/注意力/残差/归一化/FFN”形状流；
9. 注入错误轴或遗漏缩放，保存红灯证据；
10. 修复并重跑，同时说明实验不能证明语义、因果或生产性能。

公开练习故意沿错误轴做 Softmax。私有答案修复轴，但你仍应能解释为什么断言失败，而不是只把 `axis=0` 改成 `axis=-1`。

## 20. 自测问题

- token ID 与 embedding 有何区别？
- 没有位置表示时，模型缺少什么信息？
- Softmax 为什么要减每行最大值？
- 注意力应沿哪个轴归一化，为什么？
- `Q/K/V` 分别承担什么计算角色？
- 为什么除以 `sqrt(d_k)`？
- padding mask 为什么必须在 Softmax 前应用？
- causal mask 防止了哪类泄漏？
- 多头输出怎样回到 `D_model` 以便残差相加？
- 注意力权重为何不是因果解释？
- 三 token NumPy 绿灯为何不能证明 GPU 或大模型训练能力？

## 21. 版本、官方资料与未验证范围

稳定原理是 Softmax、矩阵投影、缩放点积、mask、加权求和、残差和归一化的数据流。可执行资产固定 CPython 3.14 与 NumPy 2.5.1；NumPy 2.5 支持 Python 3.12–3.14。作为 API 对照，截至 2026-07-24 PyTorch 稳定版/文档为 2.13；其 `torch.nn.functional.scaled_dot_product_attention` 文档说明默认尺度为 `1/sqrt(query.size(-1))`，且该 API 仍标为 beta，并特别提醒评估时要显式把 dropout 概率设为零。本章不调用该 API，因此不声称核验了它的任何后端。

一手资料：

- [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- [NumPy 2.5.0 Release Notes](https://numpy.org/doc/stable/release/2.5.0-notes.html)
- [NumPy 2.5.1 on PyPI](https://pypi.org/project/numpy/2.5.1/)
- [NumPy Softmax example and exp reference](https://numpy.org/doc/stable/reference/generated/numpy.exp.html)
- [PyTorch scaled_dot_product_attention](https://docs.pytorch.org/docs/stable/generated/torch.nn.functional.scaled_dot_product_attention.html)
- [PyTorch Reproducibility](https://docs.pytorch.org/docs/stable/notes/randomness.html)
- [PyTorch 2.13 Release Blog](https://pytorch.org/blog/pytorch-2-13-release-blog/)

已验证：CPU/float64 上三个 token 的 Q/K/V、缩放分数、稳定 Softmax、行和、加权输出与形状追踪。未验证：分词器质量、位置外推、训练、梯度、PyTorch 内核、GPU/MPS/CUDA、Flash/FlexAttention、混合精度、长上下文性能、真实语言能力、因果解释、线上服务、真实 FactoryCare 数据与业务收益。任何这些都不能由小矩阵绿灯推断。
