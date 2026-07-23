---
schema_version: 2
edition: 2026.2-draft
id: ch.python.modules-packages
title: 模块、包、导入与项目布局
responsibility: 用模块、包、绝对/相对导入和 main 入口组织代码，解释导入执行与循环导入，不在本章读写文件。
volume: '12'
order: 7
level: L1-L2
status: drafting
path: book/volume-12-python-data/chapters/ch.python.modules-packages.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.typing-foundations
version_surfaces:
- python-3.14
- uv
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“模块、包、导入与项目布局”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-module-import
  - python-project-layout
  covers_topics:
  - python.module
  - python.package-init
  - python.absolute-relative-import
  - python.import-execution
  - python.module-cache
  - python.src-layout
  - python.main-guard
  - python.module-cli-entry
  - python.circular-import
  uses_capabilities:
  - python.language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“模块、包、导入与项目布局”构建可运行程序与测试：把单文件工单脚本拆成 src 包、CLI 入口和可导入服务模块；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-module-import
  - python-project-layout
  covers_topics:
  - python.module
  - python.package-init
  - python.absolute-relative-import
  - python.import-execution
  - python.module-cache
  - python.src-layout
  - python.main-guard
  - python.module-cli-entry
  - python.circular-import
  uses_capabilities:
  - python.language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: module-run-import-trace-cycle-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“依赖 cwd 的导入、副作用导入或循环导入造成的启动失败”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-module-import
  - python-project-layout
  covers_topics:
  - python.module
  - python.package-init
  - python.absolute-relative-import
  - python.import-execution
  - python.module-cache
  - python.src-layout
  - python.main-guard
  - python.module-cli-entry
  - python.circular-import
  uses_capabilities:
  - python.language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 模块、包、导入与项目布局

> 本章状态为 `drafting`。正文与配套资产按 Python 3.14 标准库语义编写；离线验证器会实际执行模块入口、导入缓存和循环依赖夹具，但没有发布到 PyPI，也没有验证任意 IDE、操作系统发行版或第三方打包平台。绿灯只证明仓库内合同，不等于所有部署环境都正确。

当程序只有十行时，把函数都放在一个文件里很方便；当它开始包含工单校验、优先级计算、命令行入口和外部适配器时，一个文件会同时承担太多责任。Python 用“模块”和“包”组织名字与依赖：一个普通 `.py` 文件通常是模块，一个含多个模块的可导入目录通常是包。导入并非简单复制文本，而是“查找模块、建立模块对象、执行模块顶层代码、把结果缓存、再把名字绑定到当前命名空间”的协议。很多循环导入、启动即发请求、换目录就报错的问题，都来自忽略这条协议。

本章从零解释模块、包、导入、`src` 布局与 `python -m`。它不读写业务文件，不讲 JSON 存储，也不提前讨论发布到公共包索引。你最终要能把一个单文件工单脚本拆成稳定依赖图，并根据首个可信异常判断是“模块没找到”“名字尚未初始化”还是“入口方式错误”。

## 1. 完成定义、资产入口与学习边界

学完后，你应能独立完成以下事情：

1. 区分脚本、模块、普通包、命名空间包和发行包，不把目录、导入名与安装项目名混为一谈；
2. 解释每个模块拥有自己的全局命名空间，以及 `import x` 和 `from x import y` 绑定了什么；
3. 预测模块顶层语句何时执行、为什么通常只执行一次，以及 `sys.modules` 缓存的作用；
4. 使用绝对导入表达跨层依赖，理解包内相对导入的点号含义与适用边界；
5. 用 `if __name__ == "__main__"` 隔离脚本入口，并用 `python -m 包.模块` 从项目根运行；
6. 建立 `src/` 项目布局，使测试不会偶然导入工作区同名文件；
7. 画出依赖方向，识别循环导入、顶层副作用、标准库同名遮蔽与依赖当前目录的脆弱写法；
8. 保存成功入口、非法参数、错误启动方式和循环依赖的可复现证据。

配套入口：

- [可导入服务与模块 CLI 示例](../../../examples/encyclopedia/ch.python.modules-packages/README.md)
- [导入路径、顶层副作用与循环导入实验](../../../labs/encyclopedia/ch.python.modules-packages/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.python.modules-packages/README.md)

本章的职责是“组织代码和名字”。下一章才负责 `Path`、编码、文件、JSON 和时间。这里出现的 CLI 只处理内存中的参数与输出；若把数据库连接、文件读取或网络请求塞进 `__init__.py`，就是越界反例。

## 2. 从名字开始：模块不是文件拼接

先看两个文件：

```python
# priority.py
def normalize_priority(raw: int) -> int:
    return min(5, max(1, raw))
```

```python
# main.py
import priority

print(priority.normalize_priority(9))
```

执行 `main.py` 时，解释器在模块搜索路径中找到 `priority.py`，创建模块对象，执行其中的函数定义语句，再把模块对象绑定到 `main` 模块的名字 `priority`。函数体不会因为定义而立即计算；`def` 的执行结果是创建函数对象并绑定名字。随后 `priority.normalize_priority` 才通过模块命名空间取出函数。

### 2.1 每个模块有自己的全局命名空间

“全局”不是整个进程共享一个字典，而是相对于当前模块而言。`priority.py` 中的全局变量属于 `priority` 模块，`main.py` 中同名变量属于 `__main__` 模块。显式写 `priority.DEFAULT_LEVEL` 比把大量名字导入当前作用域更容易追踪所有者。

```python
import factorycare.priority as priority

level = priority.normalize_priority(9)
```

别名只改变当前模块中的绑定名，不会改模块真实导入名，也不会复制模块。两个引用仍可指向同一个模块对象。

### 2.2 三种常见导入形式

```python
import factorycare.priority
from factorycare import priority
from factorycare.priority import normalize_priority
```

第一种在当前作用域保留完整包名；第二种绑定子模块 `priority`；第三种直接绑定函数。第三种最短，却会隐藏名字来源，重构时也更容易与本地函数冲突。项目代码不必机械禁止 `from`，但公开所有者和可读性应优先。

`from module import *` 会让当前命名空间的来源模糊，静态工具也更难判断名字。交互式探索偶尔可用，业务模块避免使用。`__all__` 可以影响星号导入的公开集合，却不是访问控制；下划线开头也只是约定，不是安全边界。

## 3. 导入协议：查找、创建、执行、缓存、绑定

理解导入时，用五步模型：

```text
调用 import
  → 根据完整模块名和搜索路径查找规格
  → 创建模块对象并预先放入 sys.modules
  → 执行模块顶层代码，填充命名空间
  → 把模块或成员绑定到导入方
```

模块在执行完成前就会进入 `sys.modules`，这是支持递归导入的重要机制，也是循环导入会看到“部分初始化模块”的原因。若 A 执行一半时导入 B，B 又从 A 读取尚未绑定的名字，异常通常会提到 partially initialized module。它不是随机缓存坏掉，而是依赖环让读取发生得太早。

### 3.1 顶层代码真的会执行

```python
# bad_config.py
print("importing config")
SETTINGS = {"mode": "training"}
```

第一次成功导入会打印文本，因为赋值与 `print` 都是顶层语句。后续普通导入通常从 `sys.modules` 取同一个对象，因此不会再次打印。不要据此把导入缓存当永久存储：新进程有新缓存，测试可清理缓存，开发服务器也可能重载进程。

顶层适合放常量、轻量定义和无害注册。它不适合发送网络请求、连接数据库、启动线程、读取依赖当前目录的文件或修改业务事实。原因不只是性能：导入顺序会改变副作用发生时机，测试仅仅收集用例也可能触发真实操作。

```python
# 更可控的设计
def build_service(settings: Settings) -> WorkOrderService:
    return WorkOrderService(settings=settings)
```

创建资源的动作进入显式函数，入口决定何时调用，测试则传入替身。导入模块只提供定义。

### 3.2 模块缓存不是函数结果缓存

```python
import sys
import factorycare.priority

assert "factorycare.priority" in sys.modules
```

缓存键是规范模块名，值通常是模块对象。删除当前变量并不必然删除缓存；重复 `import` 也不会重新计算模块里的业务函数。需要刷新配置时应设计明确的读取接口，不要在生产逻辑里依赖 `importlib.reload()`。重载已有实例、其他模块持有的旧函数引用和线程状态都可能留下混合世界。

## 4. 模块搜索路径：为什么换目录就坏

解释器必须先知道“去哪里找”。搜索路径可通过 `sys.path` 观察，它受入口方式、当前环境、安装位置和 `PYTHONPATH` 等因素影响。重点不是背每一项顺序，而是避免把偶然存在的工作目录当项目合同。

假设目录如下：

```text
project/
├── src/
│   └── factorycare/
│       ├── __init__.py
│       ├── cli.py
│       └── priority.py
└── tests/
```

在没有安装项目、也没有设置 `PYTHONPATH=src` 时，直接执行：

```bash
python src/factorycare/cli.py
```

解释器会把脚本所在目录放到搜索路径前部，`cli.py` 被当作顶层脚本，而不是 `factorycare` 包中的模块。包内相对导入可能报“no known parent package”。更稳定的开发方式是把项目以可编辑方式安装到隔离环境，然后从项目根运行：

```bash
uv run python -m factorycare.cli --priority 5
```

若只是本章的离线夹具，也可以显式设置 `PYTHONPATH=src`；但那是验证器声明的测试合同，不应成为生产部署的隐式秘密。

### 4.1 不要用 `sys.path.append` 修补布局

在业务代码中动态拼接父目录常让本机“能跑”，却把错误推给 CI、IDE 或容器：

```python
# 脆弱反例
import sys
sys.path.append("../src")
```

相对路径仍依赖当前工作目录，而且可能把错误版本放到搜索路径前面。正确修复通常是明确项目根、采用 `src` 布局、在虚拟环境安装项目、用模块入口运行，并让测试与生产使用相同导入名。

### 4.2 同名遮蔽是常见首因

若项目根有 `json.py`、`typing.py` 或 `enum.py`，`import json` 可能导入本地文件而非标准库，继而出现“标准库缺少某属性”的怪错。诊断时打印或检查：

```python
import json
print(json.__file__)
print(json.__spec__)
```

不要只反复重装 Python。先确认实际导入了谁，再重命名冲突文件并清理生成缓存。安全上也要警惕不受信目录进入 `PYTHONPATH`，因为导入会执行代码。

## 5. 包与 `__init__.py`

包为模块名提供层级。例如 `factorycare.workorders.priority` 表示 `priority` 子模块位于 `factorycare.workorders` 包中。对初学项目，显式放置 `__init__.py` 能让边界更清楚：

```text
src/factorycare/
├── __init__.py
├── cli.py
└── workorders/
    ├── __init__.py
    ├── model.py
    └── service.py
```

现代 Python 也支持没有 `__init__.py` 的命名空间包，用于一个逻辑包跨多个目录或发行物的场景。它不是“忘了创建文件也没关系”的理由。普通业务应用默认用普通包，等确有多发行物扩展需求再引入命名空间包。

### 5.1 `__init__.py` 应保持克制

它可以为空，也可重新导出少量稳定公共 API：

```python
from .service import normalize_priority

__all__ = ["normalize_priority"]
```

重新导出缩短调用路径，但也扩大包初始化依赖。若 `service` 又反向导入包根，就容易产生环。因此先让叶子模块依赖稳定模型，包根只做轻量公开，不要把所有内部名字都汇总成“万能入口”。

### 5.2 目录名、导入名与发行名

三者可能不同：仓库目录可叫 `factorycare-ai`，安装发行名可用连字符，代码导入名通常是 `factorycare_ai`。本章聚焦可导入包，不要求发布。看到 `ModuleNotFoundError` 时，需要问的是当前解释器环境里有没有对应导入包，而不是只看仓库文件夹是否存在。

## 6. 绝对导入与相对导入

绝对导入从顶层包写起：

```python
from factorycare.workorders.model import WorkOrder
```

相对导入基于当前模块所属包：

```python
from .model import WorkOrder
from ..shared.clock import Clock
```

一个点表示当前包，更多点逐级向父包。相对导入只能出现在拥有包上下文的模块中；把文件直接作为脚本执行时，它往往没有可用父包。

本路线建议：跨领域或跨顶层层级使用绝对导入，让依赖方向一眼可见；一个小包内部可审慎使用相对导入，降低顶层包改名成本。两者不是性能之争。无论选哪种，都不能让领域层反向依赖 CLI 或基础设施层。

```text
cli → application/service → domain/model
                       ↘ ports
infrastructure/adapters → ports/domain
```

箭头表示“左侧导入右侧”。底层模型不应导入上层入口。依赖图保持单向，循环导入会自然减少。

## 7. `__name__`、主模块与 main guard

每个模块都有 `__name__`。作为普通模块导入时，它通常是完整模块名；作为启动入口执行时，入口模块的 `__name__` 是 `"__main__"`。

```python
def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    print(normalize_priority(args.priority))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

这段结构有四个好处：导入不会自动运行 CLI；`main` 可直接测试；返回值能成为进程退出码；入口副作用集中。`SystemExit(0)` 表示成功，非零通常表示失败。业务函数不应到处调用 `sys.exit`，否则库调用方无法正常组合。

### 7.1 `python file.py` 与 `python -m package.module`

前者按文件路径启动，后者先按模块系统定位，再把该模块作为主模块执行。包内入口应优先使用 `-m`：

```bash
python -m factorycare.cli --priority 4
```

它使包上下文与绝对导入一致。若包提供 `__main__.py`，还可运行：

```bash
python -m factorycare
```

`__main__.py` 通常只是薄适配器：导入 `cli.main` 并传递退出码。不要复制一份业务实现，否则两个入口会漂移。

### 7.2 入口参数也不可信

模块组织并不替代输入校验。CLI 收到的字符串应解析、校验并在错误时返回稳定非零码。包层不应信任“因为参数来自本机就安全”。真实系统的用户、脚本、CI 都可能传入空值或极端值。

## 8. `src` 布局为什么值得使用

扁平布局把可导入包放在仓库根。测试从根目录运行时，即使项目没有正确安装，也可能碰巧导入源码；构建包漏文件的问题因此被掩盖。`src` 布局把包放到 `src/` 下，迫使开发环境通过安装或显式测试配置获得它。

```text
factorycare-python/
├── pyproject.toml
├── README.md
├── src/
│   └── factorycare/
│       ├── __init__.py
│       ├── __main__.py
│       ├── cli.py
│       └── workorders/
└── tests/
```

`src` 不是 Python 语法，也不自动解决所有导入。它是减少“工作区偶然可见”的工程约束。结合 uv 时，项目声明依赖与可安装包，`uv sync` 建立环境，`uv run` 在该环境运行；具体锁定命令以项目 `pyproject.toml` 和 lockfile 为准。

### 8.1 最小 `pyproject.toml` 的职责

它可声明项目元数据、Python 版本、依赖、构建后端、工具配置与 CLI 脚本。不要把它当成“为了 IDE 不报红”的文件。构建后端选择、打包发现规则和依赖范围会影响最终工件，本章只要求能解释这些职责，详细发布留到生产化卷。

```toml
[project]
name = "factorycare-training"
version = "0.1.0"
requires-python = ">=3.14,<3.15"

[project.scripts]
factorycare = "factorycare.cli:main"
```

上面的脚本入口表示安装后创建命令，调用 `factorycare.cli` 中的 `main`。它仍应与 `python -m factorycare` 共用同一函数，而不是三套逻辑。

## 9. 循环导入：依赖图发出的设计警报

构造最小失败：

```python
# assignment.py
from factorycare.notification import build_message

DEFAULT_ASSIGNEE = "tech-7"

def assign() -> str:
    return build_message(DEFAULT_ASSIGNEE)
```

```python
# notification.py
from factorycare.assignment import DEFAULT_ASSIGNEE

def build_message(name: str = DEFAULT_ASSIGNEE) -> str:
    return f"assigned to {name}"
```

导入 `assignment` 时，它先导入 `notification`；后者立即从尚未执行到常量定义的 `assignment` 取名字，于是失败。仅交换语句顺序也许暂时通过，却保留结构性环，下一次修改会复发。

### 9.1 优先修依赖方向

常见修法：

1. 把双方共享且稳定的值或类型提取到更底层模块；
2. 让 orchestration 层负责组合，两个叶子模块互不导入；
3. 通过参数传递依赖，而不是从对方模块读取全局对象；
4. 类型标注造成的运行时环可在确有需要时配合延迟注解与 `TYPE_CHECKING`，但不能掩盖真实业务依赖环。

```python
# model.py
DEFAULT_ASSIGNEE = "tech-7"

# notification.py
def build_message(name: str) -> str:
    return f"assigned to {name}"

# assignment.py
from .model import DEFAULT_ASSIGNEE
from .notification import build_message
```

函数内局部导入可打破执行时机的某些环，但通常只是迁移症状。插件注册、可选重量依赖等场景可能合理；业务核心先重画依赖图。

### 9.2 如何读循环导入日志

按以下顺序：

1. 找异常类别：`ImportError`、`AttributeError` 或 `ModuleNotFoundError`；
2. 找“partially initialized”或“most likely due to a circular import”等线索；
3. 从 traceback 最早进入自己项目的导入链开始画箭头；
4. 确认被读取名字在目标模块何时绑定；
5. 修复依赖方向后，从干净新进程重跑原入口与测试。

不要只删除 `__pycache__` 就宣布修好。字节码缓存不会创造源码中的依赖环；新进程复现仍失败才是关键证据。

## 10. 导入副作用、重复身份与状态陷阱

### 10.1 同一源码被当成两个模块

若既直接运行包内文件，又以规范包名导入，同一源码可能分别拥有 `__main__` 和 `factorycare.cli` 两种身份。顶层单例、类对象和注册表因此可能重复。一个类即使源码相同，来自两个模块对象时身份也可能不同，`isinstance` 判断会令人困惑。

规则是统一入口与规范导入名，不混用“包内直接脚本”和“模块运行”。

### 10.2 可变模块全局状态

```python
registered_handlers: list[str] = []

def register(name: str) -> None:
    registered_handlers.append(name)
```

模块缓存意味着列表在进程内共享。测试顺序、重试和并发可能污染结果。常量可以放模块级；可变业务状态应归属于显式对象、请求作用域或受控存储。若确需注册表，提供幂等规则、清理方法和隔离测试。

### 10.3 `__init__.py` 的隐蔽成本

用户写 `import factorycare.workorders.model` 时，父包初始化也会发生。若包根为了“方便”导入所有子模块，一次精确导入可能加载整套应用，放大启动时间和循环风险。测量导入成本可以用解释器自带导入时间诊断选项；最终仍要通过拆边界解决，不以懒惰魔法掩盖。

## 11. FactoryCare 分层示例

本路线中 Java 拥有业务事实与公共 API，Python 只拥有 AI 计算和可重建派生数据。Python 包布局仍应反映这条边界：

```text
src/factorycare_ai/
├── __init__.py
├── __main__.py
├── cli.py
├── application/
│   └── summarize_work_order.py
├── domain/
│   └── suggestion.py
├── adapters/
│   └── java_client.py
└── diagnostics/
    └── import_report.py
```

`domain` 不导入 HTTP 客户端，`application` 通过端口组合能力，`adapters` 实现外部交互，`cli` 只解析参数与组装。Python 不能因为“模块里能写”就直接更新核心工单状态；那是架构授权边界，而非技术限制。

一个安全的内存示例：

```python
# domain/suggestion.py
def normalize_summary(text: str) -> str:
    cleaned = " ".join(text.split())
    if not cleaned:
        raise ValueError("summary must not be blank")
    return cleaned
```

```python
# application/summarize_work_order.py
from factorycare_ai.domain.suggestion import normalize_summary

def build_suggestion(raw_text: str) -> dict[str, str]:
    return {"kind": "DRAFT", "summary": normalize_summary(raw_text)}
```

结果明确标成草稿，不更新 Java 业务事实。模块依赖方向与业务权限方向相互印证。

## 12. 诊断阶梯：从失败阶段找首证据

### 12.1 `ModuleNotFoundError`

它通常表示完整导入名在当前解释器的搜索路径不可见。检查：实际 Python 路径与版本、虚拟环境、项目是否安装、当前入口方式、包名拼写、是否缺 `__init__.py`、是否错误依赖 cwd。先不要修改全局 `PYTHONPATH`。

```bash
type -a python python3
python -c 'import sys; print(sys.executable); print(*sys.path, sep="\n")'
python -c 'import factorycare; print(factorycare.__file__)'
```

### 12.2 `ImportError: cannot import name ...`

可能是名字根本不存在、版本不匹配、拼写错误，或目标模块仍在部分初始化。看完整 traceback 与目标模块实际文件，不要只看最后一行。

### 12.3 `attempted relative import with no known parent package`

通常是把包内模块当文件直接执行。回到项目根，以 `python -m package.module` 运行，或通过安装后的 console script 启动。不要把相对导入全改成不完整顶层导入来迁就错误入口。

### 12.4 IDE 能跑，终端不能跑

IDE 可能自动把源码根加到搜索路径或选择了另一个解释器。比较解释器绝对路径、工作目录、环境变量和运行配置。最终以仓库命令为可复现入口，IDE 配置只是方便层。

## 13. 测试模块边界，而不只测试函数结果

本章的测试需要覆盖：

| 维度 | 成功 | 边界 | 失败 |
| --- | --- | --- | --- |
| 可导入性 | 从项目根导入服务 | 重复导入返回同一对象 | 错误搜索路径找不到包 |
| CLI | `python -m` 返回 0 | 最小/最大优先级 | 非整数或越界返回非零 |
| 副作用 | 导入不输出、不改业务状态 | 两次导入保持稳定 | 顶层执行动作被探针发现 |
| 依赖图 | 单向导入 | 类型引用不触发运行时环 | 循环夹具在可信位置失败 |

`import` 成功不证明 CLI 正确，CLI 成功不证明包可被库调用。分别验证能把故障定位到正确阶段。配套示例的 `verify.sh` 使用新进程运行入口，再在进程内检查缓存；实验目录保存故意失败夹具并断言错误分类。

## 14. 常见误区与更可靠规则

**误区一：文件存在就一定能导入。** 导入依赖规范名字、搜索路径、环境与包结构。规则：在目标环境用规范导入名验证。

**误区二：`import` 只是声明。** 顶层语句会执行。规则：把外部操作放进显式函数，由入口调用。

**误区三：循环导入只要调换顺序。** 顺序补丁脆弱。规则：画依赖图，把共享概念下沉或通过参数组合。

**误区四：相对导入更低级。** 它只是基于包上下文解析。规则：内部邻近模块可用，跨边界优先绝对导入。

**误区五：`src` 自动解决路径。** 它需要安装或明确测试配置。规则：让 CI 从干净环境安装后验证。

**误区六：下划线名字是私有安全机制。** Python 主要依赖约定。规则：真正权限在调用与数据边界执行。

**误区七：删除缓存能修所有导入。** 缓存最多影响观察，不修源码依赖。规则：新进程重跑并修图。

## 15. 独立构建任务

把下面单文件概念拆成包，但不要添加文件或网络 I/O：

```python
def normalize_priority(value: int) -> int:
    if not 1 <= value <= 5:
        raise ValueError("priority must be between 1 and 5")
    return value

print(normalize_priority(int(input("priority: "))))
```

要求：

1. `domain/priority.py` 只拥有纯业务函数；
2. `cli.py` 解析参数并返回退出码；
3. `__main__.py` 只调用 `cli.main`；
4. 从根目录用 `python -m 包名` 运行；
5. 导入领域模块不打印、不读取输入；
6. 保存优先级 1、5、0、非整数四个证据；
7. 故意制造一次 CLI 与 domain 相互导入，记录首个可信 traceback，再通过下沉依赖修复；
8. 写 120 秒讲解，说明为什么 `main guard` 不是输入校验。

## 16. 自检问题

1. 模块首次导入为什么可能执行代码，第二次普通导入为什么通常不执行？
2. `sys.modules` 在循环导入时为什么包含“尚未完成”的模块？
3. 包内相对导入在直接运行文件时为何失去父包？
4. `python -m factorycare.cli` 与 `python src/factorycare/cli.py` 的模块身份有什么不同？
5. `src` 布局主要防止哪一种假绿？
6. 为什么 `__init__.py` 中批量重新导出会放大循环风险？
7. 如何确认 `import json` 实际导入了标准库而非本地 `json.py`？
8. 局部导入什么时候可能合理，为什么不是默认修环方案？
9. `from x import y` 的 `y` 在当前命名空间中由谁拥有？
10. FactoryCare Python 包为什么不能导入数据库适配器后直接更新核心工单状态？

若你只能背命令，不能从 traceback 画出依赖箭头，本章尚未完成。

## 17. 官方资料与版本说明

以下链接在 2026-07-24 按 Python 3.14 文档核对：

- [Python 3.14 教程：Modules](https://docs.python.org/3.14/tutorial/modules.html)：模块定义、搜索路径、包、绝对与相对导入；
- [Python 3.14 语言参考：The import system](https://docs.python.org/3.14/reference/import.html)：模块查找、加载、缓存与包语义；
- [Python 3.14 `__main__` 文档](https://docs.python.org/3.14/library/__main__.html)：顶层代码环境、main guard 与包入口；
- [Python Packaging User Guide：src layout](https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/)：`src` 与扁平布局的工程差异；
- [uv 项目文档](https://docs.astral.sh/uv/concepts/projects/)：项目环境、运行与锁定模型。

模块、包、main guard 与导入缓存属于稳定核心；uv 的具体命令、Python patch 版本和打包工具默认值是版本表面。升级后应重新执行示例、入口矩阵和循环夹具，不能只改版本文本。

## 18. 本章小结

模块负责一个命名空间，包负责组织模块名，导入负责查找、执行、缓存与绑定，入口负责决定何时真正启动应用。稳定项目让规范导入名、依赖方向与运行命令保持一致：`src` 布局减少偶然可见，`python -m` 保留包上下文，main guard 隔离导入与执行，单向依赖图消除结构性循环。

最可复用的规则是：**导入应提供定义，不应偷偷启动业务；先修依赖方向，再修导入语法；所有“能跑”都要说明从哪个目录、哪个解释器、以哪个模块名运行。**
