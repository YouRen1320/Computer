---
schema_version: 2
edition: 2026.2-draft
id: ch.foundations.testing-oracles
title: 预期值、测试预言、断言、AAA 与测试层级
responsibility: 建立从需求到可复现预言的验证方法，不绑定某一语言测试框架
volume: '00'
order: 12
level: L1
status: drafting
path: book/volume-00-computer-foundations/chapters/ch.foundations.testing-oracles.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.cli-streams-exit-codes
version_surfaces: []
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释预期值、测试预言、断言、AAA 与测试层级的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - test-oracle
  - test-evidence
  covers_topics:
  - test.expected-actual
  - test.oracle
  - test.assertion-aaa
  - test.positive-negative-boundary
  - test.levels-t0-t4
  - test.first-trustworthy-evidence
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：把一个金额规则拆为 AAA 测试表，覆盖正常、零值、边界与非法输入，并标明 T0–T4 中当前所用层级
  covers_topic_groups:
  - test-oracle
  - test-evidence
  covers_topics:
  - test.expected-actual
  - test.oracle
  - test.assertion-aaa
  - test.positive-negative-boundary
  - test.levels-t0-t4
  - test.first-trustworthy-evidence
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.verification-debug-test
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 从一组只有 BUILD SUCCESS、期望值写错和未执行测试的日志中定位无效 oracle，修正后制造一次真实失败再恢复
  covers_topic_groups:
  - test-oracle
  - test-evidence
  covers_topics:
  - test.expected-actual
  - test.oracle
  - test.assertion-aaa
  - test.positive-negative-boundary
  - test.levels-t0-t4
  - test.first-trustworthy-evidence
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.verification-debug-test
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 预期值、测试预言、断言、AAA 与测试层级

程序运行并打印了一个数字，并不等于数字正确；构建命令返回 `BUILD SUCCESS`，也不等于业务测试执行过；八个测试全绿，还可能只是八个测试与实现犯了同一个错误。验证的起点不是“有没有绿色图标”，而是先回答：在执行之前，我们凭什么知道什么结果才算对？

这个判定依据叫测试预言（test oracle）。预言把需求、规则或可信事实转成可比较的预期；断言再把预期和实际观察连接起来。测试通过只表示当前观察满足当前预言，不自动证明预言正确、输入覆盖完整或整个系统安全。本章建立这一条证据链，不绑定 JUnit、pytest、RSpec 或其他框架。

## 本章要解决的问题

完成本章后，你应当能够：

1. 在运行前写下 expected，并说明它来自哪条独立规则；
2. 区分 expected、actual、oracle、assertion 与测试结果；
3. 用 Arrange—Act—Assert 把准备、动作和判定分开；
4. 为规则选择正常、零值、边界和非法输入，而不是只堆“看起来不同”的样例；
5. 用本书 T0—T4 层级准确表述已经验证与尚未验证的范围；
6. 从日志中找到本次运行的首个可信失败证据；
7. 故意制造一个真实缺陷，证明测试会红，再恢复实现并复跑至绿。

先修前置能力：本章命令依赖 stdin、stdout、stderr 和退出码。如果还不能解释为什么“预期失败且 exit 1”可能是一次成功的验证实验，请先复习命令行流与退出码。

## 一、expected 和 actual 是两个不同角色

假设 FactoryCare 按“每开始一个 30 分钟块”收取人工费。每块 5000 分，配件费 1000 分，维修耗时 60 分钟。手算得到：

`2 × 5000 + 1000 = 11000` 分。

这里的 `11000` 是 expected，即执行前依据规则得到的预期值。调用报价函数后返回的值是 actual，即被测对象在本次输入、本次环境下产生的实际观察。断言比较两者：

- `actual == expected`：这个观察与这个预言一致；
- `actual != expected`：至少有一处不一致，需要调查规则、预言、实现、数据或环境；
- 没有取得 actual：可能在准备、加载、配置或调用阶段发生了错误，不能伪装成业务断言失败。

顺序至关重要。若先运行得到 `10500`，再把 expected 写成 `10500`，你记录的是实现行为，不是独立预言。它可用于刻画未知遗留行为，但不能单凭自己证明行为符合需求。做学习实验时，先把 expected 写进表格，再运行。

### 相等能证明什么

一次相等只支持一个有限命题：在已知测试版本、给定输入和环境中，被观察到的输出满足所写预言。它不能单独证明：

- 预言忠实表达了业务意图；
- 所有输入都正确；
- 未观察的数据库写入、日志、事件或计费副作用正确；
- 并发、网络、时钟、权限、性能与安全属性正确；
- 测试真的执行了目标代码而非替身、缓存结果或错误入口。

这不是贬低测试，而是给证据标边界。准确说“小范围内已经有证据”，比笼统说“系统没问题”更专业。

## 二、测试预言是判定规则，不是预测语气

测试预言回答：“对于这个输入和上下文，什么可观察结果应当被接受？”结果可以是具体值、异常类别、状态变化、集合关系、顺序、不变量或允许范围，并不总是单个数字。

常见预言来源包括：

1. 已澄清的业务规则与验收示例；
2. 协议、标准或公开契约；
3. 人工可核算的简单模型；
4. 与生产实现独立的参考实现；
5. 数学性质与不变量，例如金额不为负、排序结果保持元素多重集；
6. 经过审查的历史基线或黄金文件；
7. 多个独立实现的差分结果。

来源并非天然可靠。需求可能含糊，历史基线可能固化旧缺陷，参考实现也可能复制算法错误，黄金文件可能因无人审阅而失真。因此每个关键 expected 最好能追溯到规则，并记录单位、舍入方式、时区、空值语义和允许误差等条件。

### 循环预言为何无效

下面的思路看似自动化，实际没有独立判定能力：

```ruby
expected = WorkOrderAmount.quote(**input)
actual = WorkOrderAmount.quote(**input)
assert_equal expected, actual
```

expected 与 actual 调用同一个实现；即使实现把 31 分钟向下取整为一块，两边仍会相等。这只证明同一调用在当前条件下重复得到同一结果。另一种常见循环是让测试逐行复制生产算法：生产代码和测试代码都写成相同的错误公式，绿色也无法区分正确与共同错误。

更好的做法是把少量关键 case 手算为字面量，例如 31 分钟应为 10000 分；或使用明显不同、易审查的参考模型。预言独立不等于必须复杂，恰恰常常应该更简单。

### 测试预言问题

有些系统难以给出完整精确答案：搜索结果可有多种正确排序，机器学习输出带概率，复杂模拟没有便宜的封闭解，人机界面还包含视觉判断。这类困难通常称为测试预言问题。可采用性质、不变量、变形关系、范围、抽样人工审查或差分测试降低困难。

例如无法预先列出一个排序实现对百万条数据的完整输出，仍可验证结果有序、长度不变、输入元素没有丢失或新增。这些预言不保证发现全部缺陷，但比“能运行完”更有判定力。应诚实记录它们没有覆盖的语义。

## 三、断言把预言变成可失败的证据

断言（assertion）是可执行判定：它取得 actual，与 expected 或某个性质比较，并在不满足时留下可定位信息。高质量失败至少回答：哪个 case、哪个规则、expected 是什么、actual 是什么。

比较下面两条输出：

- `test failed`
- `thirty-one-minutes-starts-two-blocks expected=10000 actual=5000`

第二条直接指向 30/31 分钟边界和舍入方向。诊断仍需验证，但搜索空间明显更小。

### Failure、Error、Skipped 与 Zero tests

不同框架名词略有差异，本章采用以下工作区分：

- **Failure**：被测动作完成，但 actual 不满足预言，例如期望 10000、实际 5000；
- **Error**：测试未能完成预期判定，例如加载文件失败、配置解析异常或出现未预期异常；
- **Skipped/Disabled**：case 被发现但按条件没有执行；
- **Zero tests**：运行器没有发现或选择任何测试，`0 failures` 不能称为通过；
- **Pass**：测试执行了目标断言，且观察满足预言。

还要结合退出码与计数。`BUILD SUCCESS` 可能只说明编译或打包阶段成功；`Tests run: 0, Failures: 0` 明确说明没有业务断言证据；一个为了教学而故意注入缺陷的命令若输出两个预期 Failure 并返回 exit 1，反而说明元实验成功杀死了缺陷。

## 四、AAA：让失败只指向一个业务动作

AAA 是 Arrange、Act、Assert 的组织方式。Bill Wake 在 2001 年发布的原始文章用这三个阶段描述测试结构；它不是某个框架的专属语法。

### Arrange：准备条件与预期

准备输入、依赖状态、固定时间和 expected。对于 31 分钟 case：

- `labor_minutes = 31`
- `block_rate_cents = 5000`
- `parts_cents = 0`
- `expected = 10000`

Arrange 不应偷偷执行待验证业务动作。若准备数据库必须调用同一个“创建工单”入口，再在 Act 中又创建一次，副作用和失败位置都会混淆。测试数据构造可以复用，但关键值应在 case 附近可读。

### Act：执行一个主要动作

Act 调用被测行为并取得 actual。理想情况下，一个测试只有一个需要解释的业务动作。这里的“一”不是机械地限制函数调用数量，而是让测试标题对应一个清晰行为。若一个 case 同时登录、创建、审批、结算和导出，失败时很难知道哪条规则被破坏。

### Assert：观察足够但不过度

Assert 比较结果和必要副作用。只断言返回值可能漏掉重复写入；断言对象的每个内部字段又会把测试绑死在实现细节。选择与行为契约相关的观察，例如金额、错误类别、记录数量与稳定标识。

AAA 是可读性模型，不要求代码一定有三段注释。简单纯函数测试可能只有三行；系统测试的 Arrange 可能很长。关键是读者能看出条件、动作和判定，且 expected 不从 actual 倒推。

## 五、用输入分类设计有杀伤力的 case

测试数量不是覆盖质量的替代品。十个都能被相同错误实现通过的 case，不如一个能区分正确与错误公式的边界 case。

### 正常、零值、边界与非法输入

对于“人工费按已开始的 30 分钟块计费，耗时为 0—1440 分钟整数”的规则，可先列：

| 类别 | 输入示例 | 预言 | 目的 |
| --- | --- | --- | --- |
| 正常 | 60 分钟、每块 5000、配件 1000 | 11000 | 验证普通两块加配件 |
| 零值 | 0 分钟、配件 1250 | 1250 | 验证零人工不制造一块 |
| 下边界内 | 1 分钟 | 5000 | 区分开始计费与向下取整 |
| 块边界 | 30 分钟 | 5000 | 验证整块 |
| 块边界外 | 31 分钟 | 10000 | 杀死向下取整缺陷 |
| 上边界 | 1440 分钟、每块 100 | 4800 | 验证允许最大值 |
| 非法范围 | -1 分钟 | `ArgumentError` | 拒绝负耗时 |
| 非法类型 | 字符串 `"30"` | `ArgumentError` | 拒绝隐式类型混淆 |

60 分钟是正常例，却无法区分向上和向下取整，因为两种算法都得到 2。1 和 31 分钟才具有区分力。边界分析通常关注刚小于、等于、刚大于阈值；等价类则选择能代表一组相同行为的输入，避免无目的穷举。

### 正例与负例不是“成功与失败日志”

正例验证允许的行为，负例验证应被拒绝的行为。负例本身执行成功时，测试应当是绿的：例如输入 -1 后观察到约定的 `ArgumentError`，说明拒绝契约生效。若程序悄悄返回金额，才是 Failure。

非法输入的预言不要只写“报错”。至少明确错误类别或稳定错误码，并在必要时验证没有副作用。过度匹配完整异常文本会使标点修改造成脆弱失败；完全不检查异常类型又可能把空指针等意外错误误认为正确拒绝。

### 浮点、时间与随机性

金额示例使用整数分，避免把二进制浮点误差混入本章核心。真实系统若使用小数，应明确精度、舍入模式和允许误差。时间测试要固定时钟与时区，随机测试要保存种子，异步测试要等待可观察条件而不是随意 sleep。否则 actual 的不稳定会掩盖预言质量。

## 六、本书 T0—T4 是证据范围，不是行业等级

FactoryCare 课程用 T0—T4 标记验证手段，定义来自本仓库课程规范，并非 ISO、ISTQB 或所有团队通用的编号。不要在外部交流中假定对方理解同一含义。

| 层级 | 本书含义 | 典型证据 | 不能单独回答的问题 |
| --- | --- | --- | --- |
| T0 | 手算、输出与退出码 | 预测表、命令 stdout/stderr、exit | 是否有自动断言持续拒绝回归 |
| T1 | 预言、断言与 pass/fail | 明确 expected/actual、故障注入红、恢复绿 | 语言框架生命周期与工程集成 |
| T2 | 语言单元测试框架 | JUnit、pytest 等的单元测试与报告 | 数据库、网络、浏览器等集成真实性 |
| T3 | Mock、集成、容器、浏览器或设备 | API/DB/容器/端到端交互证据 | 全系统性能、安全与恢复能力 |
| T4 | 系统、性能、安全与恢复 | 负载、渗透、故障恢复与系统验收 | 所有未知风险均消失 |

本章公开运行器属于 **T1**：它有显式字面预言、断言、测试计数、正常与故障路径，但故意不使用语言单元测试框架。它不是 T2，也没有启动数据库、HTTP 服务或浏览器，因此不声称覆盖 T3；更没有性能、安全或灾难恢复证据，因此不属于 T4。

层级高不代表自动更好。低层反馈快、定位清晰，高层更接近真实集成但运行慢、变量多。常见策略是用多个层级回答不同问题，而不是用一个昂贵端到端用例替代所有单元预言，也不是拿大量单元测试声称真实部署一定可用。

## 七、首个可信失败证据决定调试起点

长日志里最后一条红字未必是根因。首个可信失败证据是：属于本次运行、来自实际执行路径、在它之前的必要阶段已经成功，并且足以推翻某个明确预期的最早观察。

可以按执行链阅读：

1. 命令与工作目录是否正确；
2. 参数和配置是否成功解析；
3. 依赖与源代码是否加载；
4. 编译或语法检查是否完成；
5. 测试是否被发现，数量是否符合预期；
6. Arrange 是否成功；
7. Act 是否真正调用目标；
8. 第一个 assertion 的 expected/actual 差异是什么；
9. 后续失败是否只是连锁反应。

若编译失败，后面缓存的旧测试报告不是本次证据，应先修编译并重跑。若 `Tests run: 0`，首要问题是发现或过滤配置，不应宣布全绿。若第一个失败为 `expected=10000 actual=5000`，且此前八个测试已发现、目标代码已加载，它才是可用于业务诊断的证据。

### 三种容易误判的日志

**只有 `BUILD SUCCESS`**：确认该构建生命周期是否包含测试、是否跳过、报告中 Tests run 是否大于零。没有这些信息，只能说构建命令成功。

**expected 写错**：若规则明确 31 分钟应计两块，但测试 expected 写成 5000，那么正确实现会红。不能为了绿色修改生产实现；应修复预言并保留规则依据，然后再故障注入验证它有杀伤力。

**测试根本未执行**：过滤表达式拼错、文件名不符合发现约定或命令只做打包，都可能出现零测试。核对测试计数与退出码，而不是只看绿色颜色。

## 八、红—绿闭环证明测试不是装饰

一个从未失败过的测试可能有价值，但它的连线尚未被验证：也许断言未执行，也许输入没进入目标分支，也许预言与实际永远相同。故障注入通过受控地引入一个已知错误，检查测试是否会拒绝它。

本章选择“把已开始块错误改为向下取整”：

- 正确公式：0 分钟为 0 块；正数为 `(minutes + 29) / 30` 的整数结果；
- 故障公式：`minutes / 30`；
- 60 和 30 分钟仍通过；
- 1 和 31 分钟失败；
- 测试应报告恰好两个 Failure、零 Error、exit 1。

完整闭环是：

1. **预测**：运行前写出绿、红、恢复绿各自的计数和退出码；
2. **初始绿**：正确实现 8/0/0、exit 0；
3. **注入红**：错误实现出现两个边界 Failure、exit 1；
4. **解释红**：首个差异能指回“已开始的块”规则；
5. **恢复**：移除故障；
6. **复跑绿**：用原命令确认 8/0/0、exit 0。

只做到红而不恢复会让工作区停在错误状态；只恢复而不复跑没有恢复证据；看到红后把 expected 改成 actual，则摧毁了预言。

受控故障注入与变异测试思想相近：故意改变比较符、边界或算术，检查测试能否杀死变异。这里不宣称执行了完整变异测试工具，只用一个透明故障教学。

## 九、运行本章的可执行证据

公开示例位于 [examples/encyclopedia/ch.foundations.testing-oracles](../../../examples/encyclopedia/ch.foundations.testing-oracles/README.md)，实验记录位于 [labs/encyclopedia/ch.foundations.testing-oracles](../../../labs/encyclopedia/ch.foundations.testing-oracles/README.md)。代码只用 Ruby 标准库，不访问网络、数据库或凭据。

从仓库根目录运行：

```bash
cd examples/encyclopedia/ch.foundations.testing-oracles
ruby run_tests.rb
ruby run_tests.rb --inject-fault
ruby run_tests.rb
ruby verify.rb
```

第二条命令预期返回 exit 1。若 shell 使用 `set -e`，它会在这里停止；这不是验证逻辑错误，而是 shell 按失败退出码中止。可以逐条执行并用 `echo $?` 记录，或直接运行 `verify.rb`，由元验证器捕获各次退出状态。

阅读资产时保持来源分离：

- [`test_cases.rb`](../../../examples/encyclopedia/ch.foundations.testing-oracles/test_cases.rb) 保存执行前确定的字面 expected；
- [`work_order_amount.rb`](../../../examples/encyclopedia/ch.foundations.testing-oracles/work_order_amount.rb) 是被测实现；
- [`run_tests.rb`](../../../examples/encyclopedia/ch.foundations.testing-oracles/run_tests.rb) 执行断言并区分 Failure 与 Error；
- [`verify.rb`](../../../examples/encyclopedia/ch.foundations.testing-oracles/verify.rb) 检查绿—红—绿与退出码。

这份极小运行器不是建议团队重造测试框架。它刻意暴露框架通常替你完成的步骤，便于零基础学习者看清 expected、actual、计数和 exit 的关系。进入具体语言章节后应使用主流测试框架，并继续保留本章的预言纪律。

## 十、从失败到修复的诊断流程

面对失败，不要立刻修改第一处能让它变绿的代码。使用可复现流程：

1. 保存原命令、版本、环境与完整输出；
2. 确认这是本次运行，测试数量与目标 case 正确；
3. 找到首个可信失败，分类为 Failure、Error、Skipped 或未执行；
4. 回到书面规则，独立复核 expected；
5. 用最小输入复现，例如从 31 分钟缩小到 1 分钟；
6. 提出能解释 expected/actual 差异的假设；
7. 只改一个相关因素并复跑同一命令；
8. 运行相邻边界和完整相关集合，避免局部修复引入回归；
9. 记录尚未验证的层级。

若 expected 错了，修 expected 是正确行为，但必须说明依据；若实现错了，修实现而不是迁就 actual；若需求含糊，暂停并澄清，而不是让测试偷偷决定产品政策；若环境错了，先恢复可执行前提，再判断业务。

### “测试通过但生产失败”并不矛盾

可能原因包括：输入类别遗漏、替身与真实依赖不一致、并发时序未覆盖、配置和数据不同、测试断言不足、预言本身错误，或生产发生了 T4 范围的资源与安全问题。正确行动是补充对应层级的证据，不是得出“测试无用”或“单元测试越多越好”的空泛结论。

## 十一、常见反模式及修正

### 反模式 1：从 actual 抄 expected

修正：先写规则、手算与单位；运行后若不同，调查而不是复制。

### 反模式 2：测试复制生产算法

修正：关键 case 使用字面结果、性质或独立模型；审查两者是否可能共同犯错。

### 反模式 3：只测顺滑正常路径

修正：围绕阈值写下刚小于、等于、刚大于；加入零值、最大值、非法范围与非法类型。

### 反模式 4：一个测试做完整业务旅程

修正：让每个 case 对应一个主要行为；系统旅程保留在相应高层，低层用更小预言快速定位。

### 反模式 5：只看最后一行或绿色图标

修正：核对命令、Tests run、Failures、Errors、skip/filter 和 exit；从执行链找首个可信证据。

### 反模式 6：用 sleep 修异步不稳定

修正：等待明确状态并设置合理超时，保留失败时的状态证据。固定延迟既慢又不能保证事件完成。

### 反模式 7：断言内部实现细节

修正：优先断言公共行为和必要副作用。除非内部结构本身就是契约，否则重构不应无故破坏测试。

## 十二、AI 参与时如何保护预言独立性

AI 可以生成测试表、边界候选和框架代码，但如果同一个提示同时要求它发明需求、实现算法和写 expected，就可能产生自洽却错误的闭环。使用下面的审查清单：

1. 每个关键 expected 能否指向用户确认的规则或独立计算？
2. AI 是否从当前实现复制了公式、字段或错误行为？
3. 是否覆盖零值、阈值两侧、上限、非法范围与类型？
4. 是否有至少一个受控缺陷能让目标 case 真实变红？
5. 测试计数是否符合预期，有无 skip、filter 或零测试？
6. Failure 是否展示 expected/actual，Error 是否被单独统计？
7. 恢复后是否用原命令复跑？
8. 当前证据属于哪个 T 层级，哪些层级明确没做？
9. 测试数据、日志或失败快照是否包含生产密钥、个人信息或敏感工单内容？

不要把真实客户数据直接交给生成工具或写入仓库夹具。使用合成数据，必要时脱敏；错误消息应保留诊断价值，同时避免泄露凭据和个人信息。

## 十三、FactoryCare 独立构建任务

独立完成时，不先查看私有答案：

1. 用一句话写出“按已开始的 30 分钟块计费”的规则、输入范围与单位；
2. 在 [worksheet.md](../../../labs/encyclopedia/ch.foundations.testing-oracles/worksheet.md) 先填八个 expected；
3. 将每个 case 标成 Arrange、Act、Assert；
4. 分类为正常、零值、边界或非法输入；
5. 预测三次运行的 Tests run、Failures、Errors 与 exit；
6. 执行初始绿、故障红、恢复绿；
7. 标出首个可信失败并解释它指向哪条规则；
8. 写明当前为 T1，以及 T2、T3、T4 没有被本实验验证的问题。

验收不是“最终全绿”四个字，而是：expected 在执行前确定；故障实现确实被拒绝；Failure 与 Error 可区分；测试数量符合预期；恢复后同一命令重新变绿；未覆盖范围写清楚。

如需加深练习，完成 [公开题目](../../../exercises/encyclopedia/ch.foundations.testing-oracles/README.md)。私有解析用于完成预测后核对，不应成为首次作答的数据源。

## 十四、120 秒复述模板

你可以按以下顺序复述：

> expected 是依据独立规则在执行前确定的可接受结果，actual 是被测对象产生的观察；oracle 提供判定依据，assertion 让不匹配变成可定位失败。AAA 分开准备、一个主要动作和判定。case 应覆盖正常、零值、阈值边界和非法输入。本书 T0—T4 描述证据范围，本章运行器只到 T1。调试先确认测试执行数量，再找本次运行的首个可信失败。反例是 expected 直接调用生产实现：实现与预言会一起犯错，测试仍全绿。

如果不能在两分钟内说出“通过不能证明什么”和一个会假绿的反例，说明概念仍需回到循环预言与零测试部分复习。

## 复习检查

不看正文回答：

1. expected 与 actual 的时间顺序和来源分别是什么？
2. 为什么 `expected = production_function(input)` 通常不是有效独立预言？
3. Failure、Error、Skipped 与 Tests run=0 有何不同？
4. 31 分钟为何比 60 分钟更能发现向下取整缺陷？
5. AAA 的 Act 为什么应保持一个主要业务动作？
6. 本章证据为何是 T1，不是 T2、T3 或 T4？
7. `BUILD SUCCESS` 后还需核对哪些信息才能说测试通过？
8. 什么叫首个可信失败？旧报告为何不能覆盖当前编译失败？
9. 故障注入后为什么必须恢复并再次运行原命令？
10. AI 同时生成实现和 expected 时，如何避免自洽假绿？

## 资料与范围声明

以下当前性声明于 **2026-07-16** 复核；本章没有以二手博客替代标准状态：

- [ISO/IEC/IEEE 29119-1:2022 — Concepts and definitions](https://www.iso.org/standard/81291.html)：ISO 官方目录在复核日列为已发布，用于核对软件测试概念标准的现行版本信息。本章没有复制付费标准正文。
- [ISO/IEC/IEEE 29119-4:2021 — Test techniques](https://www.iso.org/standard/79430.html)：ISO 官方目录在复核日列为已发布，用于核对测试技术标准的版本与范围。本章具体分类是教学化解释，不声称逐条复现标准。
- [The Oracle Problem in Software Testing: A Survey](https://discovery.ucl.ac.uk/id/eprint/1471263/)：UCL 机构库中的原始论文记录与作者稿，用于“测试预言问题”及预言技术的研究背景。
- [3A — Arrange, Act, Assert](https://xp123.com/3a-arrange-act-assert/)：Bill Wake 的原始文章，用于 AAA 的历史来源与基本组织方式。
- [课程章节规范](../../../curriculum/chapters/README.md)：本书 T0—T4 的规范来源。该编号是 FactoryCare 仓库内部术语，不是行业统一等级。

本章的金额范围、故障数量、运行器设计和诊断顺序属于可执行教学契约或作者判断；它们不是 ISO 强制要求。框架发现规则、覆盖率指标、Mock 设计、数据库集成、并发测试、性能、安全与恢复只标出边界，留待后续专章。
