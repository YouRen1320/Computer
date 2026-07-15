# 第 36 周：Python 语法、类型、控制流、集合、函数与模块

## 定位

本周把 Python 从“跟 AI/PyTorch 示例写过”还原成可解释的通用语言基础。先掌握运行、对象/名称、容器、控制流、函数和模块，再在 Week 37 学类、异常、文件和工程化，Week 38 才进入 async/FastAPI。

时间预算：15—18 小时。使用 `uv` 建立隔离项目，但不引入 Web/AI 框架。

## 前置

- G5 多端阶段通过或按明确回退节点进入 Python；
- `python --version`/`uv --version` 可用，能创建项目和运行测试；
- 已有 Java/JS/TS/Dart 经验，可比较但不套用语义；
- 不把 notebook 单元执行成功当可维护 Python 工程。

## 目标

- 理解 Python 源码、解释器、模块、包和虚拟环境的基础关系；
- 使用名称绑定、内置类型、运算、字符串和显式转换；
- 理解可变/不可变、相等/身份、truthiness、`None`；
- 使用 list/tuple/dict/set 和切片/推导式；
- 使用 if/match/for/while 与 iterator 基础；
- 设计函数、参数、返回值、作用域、closure 和类型提示；
- 拆分模块、使用 import、处理 `__name__ == "__main__"`；
- 用纯 Python 实现并测试 FactoryCare 统计规则。

## 完整概念清单

### 运行模型与工具

- CPython、源码、bytecode/VM 高层概念；
- script、module、package、project；
- REPL 适合实验，不替代可重复脚本；
- `python -m` 与直接运行文件的 import 上下文差异；
- virtual environment、project dependency、lockfile；
- `uv run`、formatter/linter/type checker/test 的角色；
- indentation 是语法，统一四空格；
- expression、statement、注释、docstring。

### 名称、对象与类型

- 变量是名称绑定到对象，不是固定类型盒；
- int/float/complex/bool/str/bytes/None；
- arbitrary precision int 与浮点误差；
- `type`、`isinstance` 和 duck typing；
- `==` 比较相等，`is` 比较身份；`None` 使用 `is None`；
- mutable/immutable 与 aliasing；
- shallow/deep copy 的边界；
- truthy/falsy，避免把 0/空字符串误判为缺失；
- 类型提示不默认在运行时强制。

### 字符串与基础 I/O

- str 是 Unicode，bytes 是字节；编码/解码边界；
- indexing/slicing、常用方法、split/join/strip；
- f-string、format spec、repr/str；
- `input` 返回字符串，转换可能抛异常；
- `print`、stdout/stderr 和返回值不同；
- 用户输入规范化和空白/大小写边界；
- 文件 I/O 留 Week 37。

### 容器

- list 有序可变、tuple 有序通常不可变、dict 映射、set 去重；
- literal、索引/切片、负索引、membership；
- append/extend/insert/remove/pop/sort 与返回值陷阱；
- dict get/setdefault/items、key 可哈希；
- set union/intersection/difference；
- unpacking、starred expression；
- list/set/dict comprehension 与可读性；
- 嵌套可变对象和浅复制风险；
- 选择容器按语义，不背 API 清单。

### 控制流与迭代

- if/elif/else、条件表达式；
- for 迭代 iterable，不是 C/Java 三段循环；
- range、enumerate、zip；
- while、break/continue、循环 else 的真实语义；
- match/case 与 pattern/guard 基础；
- iterable/iterator、`iter/next` 和 StopIteration 只建立模型；
- 修改遍历中的容器风险；
- generator 留 Week 37 深入。

### 函数与作用域

- def、return、无显式 return 得到 None；
- positional-only、positional-or-keyword、keyword-only 参数；
- default、`*args`、`**kwargs` 和 unpack call；
- 可变默认参数只创建一次的经典故障；
- 参数按对象共享/绑定语义，不能简单叫按引用；
- LEGB scope、global/nonlocal 的边界；
- function 是一等对象、closure、lambda 仅适合简单表达式；
- 类型提示、`list[T]`、`dict[K,V]`、`T | None`；
- 函数职责、纯函数、副作用和可测试性。

### 模块与导入

- import module/from import/alias；
- 模块通常首次导入执行一次并缓存；
- absolute/relative import 的项目边界；
- `__name__` 和 CLI 入口；
- 循环 import 和顶层副作用；
- `__init__.py`、package exports 基础；
- 配置/密钥不硬编码在模块全局；
- 不创建无边界 `utils.py`。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 运行/类型/字符串 | 2—3h | CLI 输入、编码和类型实验 |
| 容器/复制 | 3h | 列表/字典/集合统计及 alias 故障 |
| 控制流/迭代 | 2—3h | 筛选、聚合、match 和循环边界 |
| 函数/作用域 | 3h | 参数形式、closure、可变默认故障 |
| 模块/类型提示 | 2h | 可运行 package 和 import 反例 |
| FactoryCare/复盘 | 3—4h | 纯 Python 规则、测试、独立修改 |

## FactoryCare 增量

- 定义 `TypedDict` 或简单字典边界，输入仍按不可信数据验证；
- 实现启用设备名称、按类别统计、按技师统计活跃工单；
- 实现状态过滤和优先级汇总，不修改输入；
- 对空列表、缺字段、`None`、未知状态和 alias 写测试；
- 把 CLI、业务函数和示例数据拆模块；
- 与 Java/TS/Dart 对比名称绑定、null/None、容器和类型提示。

## 无 AI 任务（120 分钟）

实现 `summarize_work_orders(orders, assignee_id=None)`：返回总数、活跃数、最高优先级、按状态计数；定义缺字段/非法状态契约，输入不被修改。提供命令行 JSON 字符串或简化文本输入（文件留 Week 37）、至少 8 条测试和类型检查结果。

## 验收

- 能解释名称绑定、可变/不可变、`==`/`is` 和 `None`；
- 能选择 list/tuple/dict/set 并说明依据；
- 能写 if/match/for/while、函数和模块入口；
- 能复现并修复可变默认参数和浅复制问题；
- `uv run` 下测试和类型/静态检查通过；
- 能独立增加一个统计字段而不重写全部函数。

## 非目标

- 不学习 class、async、FastAPI、Pydantic 或 PyTorch；
- 不做晦涩 Python golf；
- 不把类型提示当运行时验证；
- 不使用 notebook 作为唯一交付。
