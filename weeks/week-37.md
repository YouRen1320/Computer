# 第 37 周：Python 类、数据模型、异常、文件、typing、pytest 与 uv

## 定位

本周把纯函数脚本升级为可维护 Python 工程。重点是对象/协议、异常与资源边界、文件/JSON、iterator/generator、类型系统、pytest 和依赖管理；异步和 FastAPI 留到 Week 38。

时间预算：15—18 小时。所有外部数据都先验证，所有资源都明确关闭。

## 前置

- 能使用 Python 类型、容器、控制流、函数、模块和基础测试；
- 能用 `uv run` 运行项目，理解环境与全局 Python 的区别；
- 纯 Python FactoryCare 统计模块可运行；
- 能读 traceback 最后业务帧和异常链。

## 目标

- 定义 class、实例/类属性、方法、构造和封装边界；
- 理解 dataclass、enum、property、继承/组合、Protocol/ABC；
- 理解常用数据模型方法，避免魔法方法滥用；
- 设计领域异常、技术异常和异常链；
- 使用 context manager 安全处理文件/资源；
- 使用 pathlib、text/bytes、CSV/JSON 和原子写入高层模式；
- 理解 iterable/iterator/generator 和惰性资源生命周期；
- 使用现代 typing、narrowing、generic、Protocol；
- 使用 pytest fixture/parametrize/fake/临时目录；
- 用 pyproject/uv 建立可重复工程。

## 完整概念清单

### 类与数据模型

- class body、instance、`__init__`、`self`；
- instance/class attribute 和共享可变 class attribute 陷阱；
- instance/class/static method 的责任；
- property 保护不变量，但不隐藏高成本 I/O；
- 名称约定 `_internal`、name mangling 的有限作用；
- `__repr__`、`__str__`、`__eq__`、`__hash__`、`__len__`、context/iteration protocol；
- `dataclass(frozen/slots)` 的生成行为与嵌套可变性；
- Enum 表达有限值，序列化需显式；
- 对象生命周期与垃圾回收不能替代资源关闭。

### 继承、组合与协议

- inheritance/MRO/super 的高层行为；
- multiple inheritance 与 mixin 的谨慎使用；
- composition/delegation 优先表达协作；
- ABC 运行时抽象基类，Protocol 静态结构契约；
- duck typing 与明确端口不冲突；
- `@runtime_checkable` 的有限检查；
- LSP 和异常/返回契约；
- repository/client port 使用 Protocol，避免框架耦合。

### 异常与资源

- BaseException/Exception、常见内置异常；
- raise、自定义异常、`raise ... from ...`；
- try/except/else/finally；
- 精确捕获、保留 traceback、不要吞异常/返回假成功；
- `with`、context manager protocol、`contextlib`；
- cleanup 在异常路径也执行；
- 批量导入 fail-fast 与收集错误；
- 日志与抛异常职责不同，不在每层重复记录同一 traceback。

### 文件、路径与序列化

- pathlib Path、相对/绝对/resolve；
- text/bytes、encoding/newline；
- read/write/append、迭代大文件；
- 用户路径、path traversal 和允许根目录；
- CSV dialect/header/type 转换；
- JSON 类型限制、datetime/Decimal/Enum 自定义映射；
- 临时文件+替换的原子写入高层模式；
- 文件缺失、权限、编码、部分写入和损坏；
- pickle 不用于不可信数据。

### iterator 与 generator

- iterable vs iterator、`__iter__/__next__`；
- generator function、yield、惰性和一次消费；
- generator expression 与 list comprehension；
- `yield from`、send/throw/close 只建立概念；
- 资源绑定 generator 的提前终止/关闭风险；
- `itertools` 常用组合按需使用；
- 惰性不自动更快，需考虑多次遍历和调试。

### typing

- annotation、`Any`、`object`、`Never`、`None`；
- union/Optional、Literal、TypedDict、NamedTuple、dataclass；
- TypeGuard/TypeIs（按当前 Python 文档核对）、narrowing；
- TypeVar、generic class/function、bound/constraint；
- Protocol、Callable、Iterator/Iterable/Generator；
- variance 直觉、可变容器不协变；
- cast 只说服检查器，不做转换；
- runtime schema 留给 Pydantic/显式 parser。

### pytest 与 uv 工程

- arrange/act/assert、test discovery；
- fixture scope、yield cleanup、避免隐藏巨型 fixture；
- parametrize、marks、raises、tmp_path、monkeypatch；
- fake/stub/mock 与 interaction/state test；
- coverage 是线索，不证明质量；
- `pyproject.toml`、dependency group、lock/sync/run；
- src layout、package import、CLI entry point；
- lint/type/test/build 在同一环境执行。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| class/dataclass/enum | 2—3h | 值对象、实体和共享属性故障 |
| Protocol/组合 | 2h | repository/client 端口和 fake |
| 异常/context | 2—3h | 异常链、资源清理和批量错误 |
| 文件/JSON/CSV | 3h | 安全导入导出与损坏输入测试 |
| typing/pytest/uv | 3h | strict 类型、fixture、临时目录、锁 |
| FactoryCare/复盘 | 3—4h | 可安装包、CLI、测试和独立修改 |

## FactoryCare 增量

- dataclass/Enum 建立文档元数据和解析结果；
- Protocol 定义 `DocumentStore`，提供内存 fake；
- 从 CSV/JSON 导入设备，收集每行错误而不吞根因；
- 安全导出工单快照，显式 UTF-8、时间和 enum；
- 使用 tmp_path 测文件缺失、路径拒绝、编码、损坏和原子替换；
- CLI 返回有意义 exit code，不打印密钥或完整敏感数据。

## 无 AI 任务（150 分钟）

实现 `DeviceCatalogImporter`：从 CSV 读取 ID、名称、类别、enabled，转换为 dataclass，重复/缺字段/非法布尔/路径越界形成结构化错误；有效行继续处理。使用 Protocol repository、pytest 参数化和临时目录，类型/测试/构建通过。

## 验收

- 能比较 dataclass/class/TypedDict/Protocol/ABC；
- 能保留异常链并保证资源关闭；
- 能解释 generator 的惰性与生命周期；
- 不用 cast/Any 掩盖不可信数据；
- uv lock、类型、lint、pytest 和 package build 可重复；
- 能独立增加 CSV 字段并更新解析、类型、错误和测试。

## 非目标

- 不学习 async/FastAPI/Pydantic；
- 不深入 metaclass/descriptor/MRO 算法；
- 不用 pickle 处理外部数据；
- 不建立通用企业 Python 框架。
