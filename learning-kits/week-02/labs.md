# Week 02 实验手册

## Lab 1：String/null 边界（90 分钟）

实现 `normalizeCategory(String raw)`：允许前后空白和大小写变化，输出稳定 code；null/blank/unknown 明确失败。

先预测：两个 `new String("PUMP")` 的 `==/equals`；`split(".")`；null 调用 `strip()`。

验收：测试 null、空、空白、已规范、大小写和未知值。

## Lab 2：数组共享与扫描（90 分钟）

实现：最大优先级、>=4 数量、首个 5 的索引（没有时 -1 或明确定义）。

故障：

- 循环写 `i <= length`；
- 复制变量后修改原数组；
- 空数组访问 `[0]`；
- 两层循环 O(n²) 后改一次扫描 O(n)。

## Lab 3：if 与 switch 决策表（75 分钟）

先写表：停机、影响人数、类别、等待小时 → priority。验证分支顺序；同一输入只能命中一个最终规则。

用 switch 只映射类别基础权重，用 if 处理跨字段提升。比较全部 if 与拆分后的可读性。

## Lab 4：for/while/do-while（90 分钟）

- for：统计数组；
- enhanced for：验证所有优先级 1—5；
- while：最多 3 次解析重试（用预设输入，不依赖真实人）；
- do-while：菜单至少显示一次的最小实验；
- 解释 break/continue/return。

## Lab 5：调试器定位（60 分钟）

在一个过早 return 的统计方法设断点。画出预期循环表，找到第一次偏离，新增回归测试，再修复。

## Lab 6：FactoryCare 优先级与批量统计（4—5 小时）

### 输入

- `String category`；
- `int affectedUsers`；
- `boolean machineStopped`；
- `int waitingHours`。

### 契约

- priority 1—5；
- 停机至少 5；安全类别至少 4；影响 >=20 提升；等待超阈值提升但不超过 5；
- 类别 null/blank/unknown、负人数/小时明确失败；
- 具体规则以先写的决策表为准。

### 批量

对优先级数组输出 urgentCount（>=4）、highest、firstCriticalIndex 和 `int[6]` 分布。空数组有明确结果。

### 测试与故障

- 每条规则一条、交叉组合、所有临界点；
- unknown/null/negative；
- 删除停机分支、乘/加错误、循环过早 return；
- 所有测试命令行通过；批量扫描 O(n)、额外空间 O(1)。

## Lab 7：关闭 AI 修改（60—90 分钟）

增加“等待 >=24 小时至少优先级 3”，先写边界 23/24 和与停机组合测试。不得重写整个计算器。

## 完成清单

- [ ] String/null 边界可解释；
- [ ] 四种循环都运行过；
- [ ] 数组扫描和复杂度正确；
- [ ] 调试器有真实定位记录；
- [ ] 决策表、实现和测试一致；
- [ ] 独立规则变化完成。
