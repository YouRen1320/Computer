---
schema_version: 2
edition: 2026.2-draft
id: ch.pytorch.inference
title: 保存、加载、推理、批处理与服务边界
responsibility: 把训练产物转换为版本化、可批处理和可服务的推理合同，验证预处理一致性、无梯度模式和错误输入，不部署生产服务。
volume: '13'
order: 15
level: L3
status: drafting
path: book/volume-13-ml-pytorch/chapters/ch.pytorch.inference.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.pytorch.training
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
  text: 在 120 秒内解释“保存、加载、推理、批处理与服务边界”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - pytorch-model-artifact
  - pytorch-inference-boundary
  covers_topics:
  - pytorch.state-dict
  - pytorch.model-config-version
  - pytorch.preprocessing-bundle
  - pytorch.artifact-integrity
  - pytorch.inference-mode
  - pytorch.batch-inference
  - pytorch.input-output-schema
  - pytorch.latency-throughput
  uses_capabilities:
  - ml.training-inference
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 导出含模型配置、权重、预处理和标签映射的版本化制品，编写单条/批量推理入口并测量延迟与吞吐；独立保存可复现工件与判断结果
  covers_topic_groups:
  - pytorch-model-artifact
  - pytorch-inference-boundary
  covers_topics:
  - pytorch.state-dict
  - pytorch.model-config-version
  - pytorch.preprocessing-bundle
  - pytorch.artifact-integrity
  - pytorch.inference-mode
  - pytorch.batch-inference
  - pytorch.input-output-schema
  - pytorch.latency-throughput
  uses_capabilities:
  - ml.training-inference
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: roundtrip-load-test-golden-prediction-batch-equivalence
- id: diagnose
  kind: fault-diagnosis
  text: 面对“只保存权重不保存结构、预处理训练/推理漂移、未启用推理模式或批次形状错误”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - pytorch-model-artifact
  - pytorch-inference-boundary
  covers_topics:
  - pytorch.state-dict
  - pytorch.model-config-version
  - pytorch.preprocessing-bundle
  - pytorch.artifact-integrity
  - pytorch.inference-mode
  - pytorch.batch-inference
  - pytorch.input-output-schema
  - pytorch.latency-throughput
  uses_capabilities:
  - ml.training-inference
  - ml.neural-pytorch
  - ml.problem-classical-evaluation
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 保存、加载、推理、批处理与服务边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《训练循环、复现、过拟合、评估与调参》](ch.pytorch.training.md)：推理制品来自已验证训练流程与可恢复检查点。
<!-- END GENERATED LEARNING PREREQUISITES -->

训练进程内的 Python 对象不是可交付模型。推理需要一份自描述制品：模型如何构造、参数是什么、原始字段怎样预处理、输出类别怎样映射、各文件是否完整、版本是否受支持。加载方必须在没有训练进程内存的全新进程中重建模型，并对黄金输入给出与导出时一致的结果。

本章构建这种最小制品与单条/批量推理入口，但不启动 HTTP 服务、不配置容器、不做线上发布。CPU 冒烟测量只记录本次本机小程序的时间，不设置性能门，也不能被引用为生产延迟、吞吐、GPU 或 MPS 结果。

## 1. 从检查点到推理制品

训练检查点面向恢复训练，可能包含优化器、epoch 和随机状态；推理制品面向稳定重建前向，只需推理相关内容，但必须比一份裸权重更完整。两者可共享 state_dict，却有不同生命周期与访问控制。

推理制品至少包含：

```text
manifest.json        制品 schema、模型 ID/版本、文件哈希
model.json           网络构造配置
weights.pt           state_dict
preprocessing.json   特征顺序、均值、尺度、dtype
labels.json          类别 ID 到稳定名称的映射
```

目录名字不是合同。每个内部文件都有 schema，manifest 列出预期文件与摘要。加载顺序是先验证清单和完整性，再解析配置、构造模型、加载权重，最后设置推理行为。

### 1.1 为什么权重不够

state_dict 里的键与 Tensor 形状无法唯一表达 Python 模块结构、激活、Dropout 参数、特征语义和标签。当前代码恰好能加载，不表示半年后还能复原。只保存权重是本章故障注入之一，加载器必须在调用 PyTorch 前因缺文件失败。

### 1.2 为什么不直接 pickle 整个 Module

整个对象可能依赖精确类路径和任意 Python 反序列化，迁移与安全风险更高。官方教程通常推荐保存 state_dict，再由受控代码构造结构。任何来自不可信来源的文件都不能随意加载。

## 2. state_dict

`model.state_dict()`是参数与持久 buffer 名称到 Tensor 的映射。它不包括 forward 源码或任意普通属性。严格加载会报告缺失和多余键，形状不匹配也会失败。

### 2.1 保存快照

state_dict 返回的 Tensor 与模型状态有关。保存“最佳状态”若只在内存变量中浅引用，后续训练可能继续改变它；可以立即 `torch.save` 或深拷贝。推理导出应从已冻结、验证通过的最佳检查点产生，而不是未知当前对象。

### 2.2 加载顺序

先读取和验证 `model.json`，按允许的配置构造 Module，然后 `load_state_dict(..., strict=True)`。严格并不验证语义：若新旧结构键和形状相同但特征含义变了，仍能加载，所以还需要模型与预处理版本。

### 2.3 map_location

制品可能在某设备保存，加载环境可能只有 CPU。显式 `map_location="cpu"` 让本章路径可审查。它不是证明其他设备兼容；转换后仍要执行黄金测试。

### 2.4 weights_only 与版本表面

当前工件调用 `torch.load(..., weights_only=True)`，只读取本程序写入的 state_dict。具体安全默认、允许类型和错误行为会随 PyTorch 版本变化，必须查目标版本序列化文档。`weights_only`降低部分风险，不把未知文件变可信。

## 3. 模型配置与版本

模型配置包含输入宽度、隐藏宽度、类别数、Dropout 等构造参数；schema 说明配置文档格式；模型版本说明业务/实验身份。三者不要混成一个字符串。

### 3.1 拒绝未知配置

示例加载器只接受精确的教学配置，未知字段或值直接失败。生产系统可实现迁移器，但每个迁移都需要源/目标 schema、测试和回滚，不应默默忽略字段。

### 3.2 模型 ID 与版本不可变

相同版本号不应指向不同字节。新权重、新预处理或标签映射都生成新版本/摘要。别用 `latest.pt` 作为审计身份；latest 只能是指向不可变版本的可回滚引用。

### 3.3 兼容性

服务若只支持 schema 1，应在加载 schema 2 时明确拒绝，而不是尽力猜。向后兼容是显式产品决策，需要迁移与停用计划；本章选择小而严格的 schema 1。

## 4. 预处理必须随制品

模型实际学习的是预处理后的张量，不是原始 JSON。训练用 `(x-mean)/scale`，推理若忘记或换统计量，即使权重完全相同，输出也会变化。这称训练—服务偏差。

示例合同：

```text
feature_order = [age_hours, alerts_7d, days_since_service]
mean          = [10, 2, 5]
scale         = [2, 1, 5]
dtype         = float32
```

原始 `[12,3,10]` 转为 `[1,1,1]`。若错误使用零均值和单位尺度，输入变 `[12,3,10]`，模型执行仍成功但语义错误。

### 4.1 字段顺序

JSON 对象看似有名称，最终 Tensor 却只有位置。预处理按配置的 feature_order 取值，不能依赖调用者字典迭代顺序。要求键集合精确一致能发现缺失和未知字段；是否允许向前兼容多余字段应单独设计。

### 4.2 类型与有限性

布尔值在 Python 是整数子类，但“true 小时”没有意义，因此显式拒绝。字符串数字、NaN 和无穷也拒绝。是否允许 `null`、默认值或裁剪必须写进 schema，不能由 Tensor 构造隐式决定。

### 4.3 尺度

scale 必须正且非零。零尺度代表训练数据该特征无变化，需要训练阶段策略；推理时临时改成 1 会使训练/服务不一致。统计量包含敏感信息时还要有访问控制。

## 5. 标签映射与输出合同

模型返回 logits `(B,C)`，argmax 得类别 ID `(B,)`。ID 只在固定 label mapping 下有意义。若训练时 0=normal、1=review，服务换序会把每个结果颠倒而无 shape 错误。

输出可包含模型版本、原始 logits/经校准概率、类别 ID和标签，但每项都要定义。示例返回 logits 与离散类别，不宣称概率校准。下游不能把 review 当必然故障。

### 5.1 黄金样本

制品附带少量人工黄金输入和预期输出，覆盖中心点、非对称点与非法输入。黄金测试不是性能评估，而是检查加载、预处理和标签是否一致。

本章已知权重下：原始均值点预处理为 `[0,0,0]`，logits `[0.1,-0.1]`，类别 normal；第二点预处理 `[1,1,1]`，logits `[-0.4,3.4]`，类别 review。数值由固定矩阵手算并逐元素断言。

## 6. 制品完整性

SHA-256 摘要能发现文件字节意外或恶意改变，但如果攻击者能同时修改文件和 manifest，普通哈希不能证明来源。生产来源认证需要签名、受控仓库、身份与审计。本章只验证内部完整性，不宣称供应链安全。

### 6.1 先验文件集合

manifest 必须列出每个必须文件。加载器先检查缺失，再计算摘要。额外文件如何处理要决定；示例忽略不相关额外文件，但不执行它们。符号链接、路径穿越和压缩炸弹是更高阶制品安全问题，本章不实现。

### 6.2 损坏演练

删除模型配置、改变预处理字节或替换权重，加载应在相应阶段失败。错误消息指出具体文件，但不要泄露敏感路径或内容。修复是重新从可信来源获得完整版本，不是跳过哈希。

## 7. 全新进程 round trip

同一进程导出后马上用原 model 对比，可能意外复用内存状态或模块配置。更强证据是启动新的 Python 进程，只传制品目录：新进程导入代码、解析所有文件、构造模型、加载 state_dict、执行黄金批次，并通过标准输出返回结构化结果。

本章 `subprocess.run([sys.executable,...])` 使用当前隔离解释器启动全新进程，`check=True`确保非零退出不会被忽略。父进程比较 logits、版本和标签逐项一致。这里的新进程仍在同一机器、同一安装中，不证明跨平台兼容。

## 8. eval 与 inference_mode

加载权重后必须 `model.eval()`，使 Dropout、BatchNorm 等采用评估行为。推理调用还在 `torch.inference_mode()` 中执行，避免记录反向图和相关开销。

两者不可互换：eval 不禁用梯度，inference_mode 不自动切模块到 eval。测试同时断言 `model.training is False` 与输出 `requires_grad is False`。

### 8.1 no_grad 与 inference_mode

二者都可禁用常规反向记录，inference mode 有更强限制和潜在优化。若推理生成的 Tensor 后续要参与需要 Autograd 的计算，应按官方说明选择 no_grad。服务纯前向路径可优先 inference_mode，但目标版本要实测。

### 8.2 不用 detach 伪装修复

先在普通 grad mode 前向再对输出 `.detach()`，虽然最终标志为 false，图已经构建并产生开销。正确做法是在前向之前进入禁用图上下文。

## 9. 输入 schema

边界接收外部数据，先校验再构造 Tensor：请求必须是非空列表；每项精确三个字段；每个值是有限数且不是布尔；预处理输出 `float32 CPU (B,3)`。错误应映射为明确客户端/数据错误，而不是让矩阵乘法产生晦涩异常。

### 9.1 单条也是批次

单条入口内部包装成长度一列表并调用同一批量实现，输出再取第 0 项。避免维护两套预处理与模型逻辑。模型始终看到 `(1,3)`，不因单条变 `(3,)`。

### 9.2 空批次

空批次是拒绝还是返回空结果需明确。示例拒绝，因为后续输出和计量语义不清。高吞吐系统可能允许空批，但必须测试 shape 和耗时统计。

### 9.3 资源限制

合法 shape 仍可含数百万行导致内存压力。生产边界还需请求大小、batch 上限、超时和并发控制；本章没有服务层，不实现这些保护。

## 10. 批量推理

批量能摊薄 Python 和调用开销，模型输入 `(B,3)` 输出 `(B,2)`。批量结果第 i 项必须与单条调用同一输入的结果相同（在相同确定性推理条件和容差内）。本章对两条黄金输入做零容差逐项比较。

### 10.1 顺序

输出顺序与输入顺序对应。并发分批合并时应携带请求 ID，不能按完成时间误排。示例同步列表天然保序，但生产队列需显式协议。

### 10.2 动态批处理

真实服务可在短窗口聚合请求，改善吞吐但增加排队延迟。最大 batch、等待时间和取消语义是服务设计，本章只讲关系，不实现动态批处理。

### 10.3 数值等价边界

不同 batch 大小、后端或算子实现可能有微小浮点差。教材固定 CPU 小模型得到完全一致；生产通常用声明容差和业务输出一致性规则，不能把一次零差推广到所有设备。

## 11. 延迟与吞吐

延迟是一次请求经历的时间分布，吞吐是单位时间处理量。二者会受 batch、并发、排队、预处理、模型、序列化、线程、热身和硬件影响。只报一个平均毫秒没有完整含义。

### 11.1 测量合同

至少记录环境、版本、设备、输入 shape、batch、预热次数、重复次数、计时边界、并发和分位数。加速器还可能需要同步，否则只测到任务提交。服务测量需包含或明确排除网络与队列。

### 11.2 本章实际测量

工件对两条输入在同一 CPU 进程中调用 100 次并用 `perf_counter`记录总耗时与粗略 items/s，不设通过阈值。输出明确标记 local sanity、not a production benchmark。每次机器负载可使数字变化，所以不写入固定正文成绩，也不与 GPU/MPS比较。

### 11.3 优化前先正确

若预处理漂移，速度再快也无意义。性能优化必须在黄金预测、批量等价和输入拒绝全部通过后进行，并防止编译/量化改变输出超出容差。本章不教授编译、量化或异步服务。

## 12. 服务边界

推理函数与生产服务不同。服务还需要进程生命周期、模型热加载、并发、限流、超时、认证、审计、健康检查、监控和回滚。一个 `predict()` 函数通过不能称“已部署”。

### 12.1 加载失败应 fail closed

缺文件、摘要错、schema 未知或黄金测试失败时，不应随机初始化后继续提供结果。服务应保持旧的已验证版本或拒绝就绪，并产生可观察事件。

### 12.2 模型版本进入响应

每个推理结果携带不可变模型版本，方便反馈和回滚。只记录服务代码版本不足以知道用了哪组权重与预处理。

### 12.3 人工兜底

模型输出为派生信号。涉及工单优先级等影响操作时，Java 业务层应用阈值、权限和人工规则，并保留申诉/覆盖记录。Python 不独占最终决策。

### 12.4 制品晋级不是复制文件

开发、候选、生产是制品的生命周期状态，不应对应三份可以分别修改的目录。一次训练得到不可变版本及摘要，验证系统记录它通过了哪些数据、环境和黄金测试；晋级只改变“允许哪个环境引用该版本”，不重新打包字节。否则开发环境验证的内容与生产实际加载的内容可能不同，原有证据失效。

一个最小晋级记录至少要有制品 ID、不可变版本、manifest 摘要、创建时间、训练代码版本、批准人或自动门、验证结果和目标环境。这里列出字段是为了说明合同，没有实现制品仓库、审批流或签名系统。模型配置、预处理或标签中任何一个字节改变，都应形成新版本并重新验证。

### 12.5 回滚先验证旧版本仍可加载

回滚不是把某个未知的“旧文件”复制回来。发布前应保留上一份已验证版本的不可变引用，并让当前服务代码能够加载它。若服务代码已经删除旧 schema 支持，即使权重仍在，紧急回滚也可能失败。因此兼容窗口、schema 迁移和旧版本停用必须一起计划。

安全切换可以采用“加载候选—校验清单—执行黄金样本—标记就绪—原子切换引用”的顺序。任一步失败都继续使用旧版本；切换后还要能按模型版本观察错误率和业务指标。这里不实现双实例或流量切换，所以只能说明协议，不能宣称热更新或零停机已经成立。

### 12.6 并发、背压与取消

同步的 `predict_batch()` 只证明函数合同。进入服务后，多个请求可能同时到达；若每个请求都无限创建任务或聚合成无限 batch，内存和等待时间都会失控。入口需要并发上限、队列容量、batch 上限、排队超时与过载响应，这一组机制称背压。它们属于服务层，不应塞进模型 forward。

客户端取消请求也不一定自动终止已经开始的模型计算。系统要区分“调用方不再等待”“任务还在队列中，可移除”和“底层计算已经运行，暂时不可抢占”。取消后的结果是否计入监控、动态 batch 中其他样本如何继续，都要有明确语义。仅捕获一个异步取消异常不足以证明计算资源已经释放。

并发还会影响性能证据。单进程顺序循环得到的 items/s，不能外推到多个 worker；线程数、进程数、CPU 核、BLAS 线程、队列等待和内存副本都可能改变延迟分布。本章不选择 worker 拓扑，只要求真正服务测试把这些条件写进测量合同。

### 12.7 成功与失败都要有输出合同

成功响应不仅是一个数字。至少应绑定请求或样本标识、模型不可变版本、类别 ID、稳定标签，以及业务确实需要的分数表示。若输出 logits，就明确它们不是概率；若输出概率，就说明 softmax、校准与精度格式。不要让调用方从数组位置猜字段含义。

失败也要分类：字段缺失、类型非法和 batch 超限属于输入合同失败；制品缺失、哈希错误和 schema 不支持属于模型不可用；内部计算异常属于服务故障。对外响应可隐藏路径和堆栈，对内日志保留阶段、模型版本、相关请求 ID 和首个可信原因。不能把所有失败都返回空列表，因为空列表会被误认为一次合法的“没有结果”。

输出 schema 的兼容规则与输入同样重要。增加可选字段通常比改变类别 ID 或数组顺序安全，但仍要经过消费者测试。Java 业务层应先验证版本与结构，再把派生结果纳入规则；若 Python 不可用，应按明确的降级政策处理，而不是悄悄把未知预测当作 normal。

## 13. 四类故障定位

### 13.1 只保存权重

失败阶段是制品预检，首证据为缺少 `model.json`、`preprocessing.json`、`labels.json` 与 manifest，而不是 state_dict 加载栈。修复重新导出完整制品。

### 13.2 预处理漂移

加载与 forward 都可能成功。首证据是黄金原始输入的预处理 Tensor 与期望不同，随后 logits 不同。逐步比较字段顺序、均值、尺度、dtype，不能先改黄金输出。

### 13.3 未启用推理模式

若只 eval，输出仍 `requires_grad=True`；若只 inference mode，Dropout 仍可能处于 train。首证据是 `model.training` 和 grad 标志。组合修复并重跑单条/批量。

### 13.4 批次形状错误

`(3,)`、`(B,2)`或`(B,3,1)`应在输入合同阶段失败。首证据是实际/期望 shape。不要无条件 flatten，它可能把多个样本或轴混在一起。

## 14. FactoryCare 边界

本章制品 ID、标签和输入均为教学构造，没有真实工单，也不代表可用优先级模型。Java 后端拥有业务事实、鉴权、工单状态和对外 API；Python 推理只返回带版本的派生结果。客户端仍调用 Java，不能直连模型绕过授权。

线上使用前还需数据授权、模型卡、公平审查、阈值政策、漂移与效果监控、人工兜底和回滚。SHA-256、全新进程加载与本地冒烟耗时只覆盖制品技术合同，不覆盖这些生产要求。

## 15. 版本与验证事实

仓库 `pytorch-stable` 状态 provisional。2026-07-24 官方稳定文档路由到 2.13，但安装入口版本文字仍存在不同步。实际隔离验证环境是 Python 3.14.3、PyTorch 2.13.0、CPU；没有执行 CUDA、MPS 或其他加速器。

state_dict、显式模型/预处理合同、批量等价是相对稳定原则；`torch.load`默认、inference mode 限制、可用设备和序列化格式是版本表面。每次升级都重跑完整性、全新进程黄金样本和错误输入测试。

## 16. 可运行工件

- `examples/encyclopedia/ch.pytorch.inference/`：完整 bundle、SHA-256、已知权重、全新进程与批量等价。
- `labs/encyclopedia/ch.pytorch.inference/`：裸权重、预处理漂移、梯度模式与 shape 故障。
- `exercises/encyclopedia/ch.pytorch.inference/`：入口故意保持训练/构图状态，初始红灯。
- `solutions-private/encyclopedia/ch.pytorch.inference/`：shape、eval 与 inference_mode 答案。

## 17. 120 秒复述模板

“推理制品不只是权重，还要有模型配置、预处理、标签、schema、版本和完整性清单。加载器先验文件与哈希，再构造模型、严格加载 state_dict、eval，并在 inference_mode 下前向。外部输入先按 schema 校验，单条复用批量实现；全新进程对黄金样本结果相同、单条与批量逐项一致才是 round trip 证据。越界反例是本机两条输入耗时很短就声称线上低延迟或 GPU/MPS 性能；本章没有服务和加速器证据。Java 仍负责业务事实和最终决策。”

## 18. 自测题

1. 为什么 state_dict 不能单独重建完整推理？
2. 模型 schema、模型版本和文件哈希各解决什么？
3. 预处理字段顺序错为何可能不报 shape 错？
4. 普通 SHA-256 能否证明发布者身份？
5. 同进程加载为何弱于全新进程？
6. eval 与 inference_mode为何都需要？
7. 单条入口为什么内部保持 batch 轴？
8. 单条/批量等价应比较什么？
9. 本机平均耗时为何不是线上 SLA？
10. 加载失败为什么不能随机初始化继续服务？

## 19. 答案要点

1. 它没有 forward 代码、结构配置、预处理和标签语义。
2. schema 管文档格式，版本管不可变模型身份，哈希管字节完整性。
3. 三列数量仍相同，矩阵合法但特征语义互换。
4. 不能；攻击者可同时改文件与清单，来源需签名/受控仓库。
5. 同进程可能复用已有对象或状态，新进程强制从制品重建。
6. eval 切行为，inference_mode 禁止图记录。
7. 保持模型 `(B,F)` 合同，避免两套逻辑。
8. 对应顺序的 logits、类别、标签和模型版本，在声明容差内。
9. 缺网络、并发、排队、负载、分位数和目标硬件等条件。
10. 会产生无来源随机结果；应保留旧版或不就绪。

## 20. 官方资料

- [保存与加载模型教程](https://docs.pytorch.org/tutorials/beginner/saving_loading_models.html)：state_dict 与检查点模式。
- [序列化语义](https://docs.pytorch.org/docs/2.13/notes/serialization.html)：保存、加载和安全边界。
- [`torch.save`](https://docs.pytorch.org/docs/2.13/generated/torch.save.html) 与 [`torch.load`](https://docs.pytorch.org/docs/2.13/generated/torch.load.html)：当前 API。
- [`torch.inference_mode`](https://docs.pytorch.org/docs/2.13/generated/torch.autograd.grad_mode.inference_mode.html) 与 [`torch.no_grad`](https://docs.pytorch.org/docs/2.13/generated/torch.no_grad.html)：禁用图记录的语义差异。
- [`nn.Module`](https://docs.pytorch.org/docs/2.13/generated/torch.nn.Module.html)：eval、state_dict 与模块生命周期。

核对日期 2026-07-24。链接指向当前稳定文档表面；本地 CPU 全新进程和黄金样本提供实际运行证据，不等同生产部署证明。
