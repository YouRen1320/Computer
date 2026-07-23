---
schema_version: 2
edition: 2026.2-draft
id: ch.python.runtime-uv
title: Python 运行时、uv、虚拟环境与依赖
responsibility: 建立 CPython、uv、虚拟环境、pyproject 与锁文件的可重复运行链，区分解释器、环境和包来源，不教授 Python 语法。
volume: '12'
order: 1
level: L1
status: drafting
path: book/volume-12-python-data/chapters/ch.python.runtime-uv.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.dependencies-build-packages
version_surfaces:
- python-3.14
- uv
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Python 运行时、uv、虚拟环境与依赖”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-runtime-environment
  - python-uv-dependencies
  covers_topics:
  - python.interpreter-resolution
  - python.venv
  - python.module-run
  - python.sys-path-intro
  - python.pyproject
  - python.uv-lock-sync
  - python.dependency-group
  - python.reproducible-environment
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从空目录创建锁定依赖的 Python 项目并记录解释器、环境和 uv 证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-runtime-environment
  - python-uv-dependencies
  covers_topics:
  - python.interpreter-resolution
  - python.venv
  - python.module-run
  - python.sys-path-intro
  - python.pyproject
  - python.uv-lock-sync
  - python.dependency-group
  - python.reproducible-environment
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: interpreter-evidence-uv-sync-run-exit-code
- id: diagnose
  kind: fault-diagnosis
  text: 面对“全局/虚拟环境混用、解释器路径漂移或锁文件未同步”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-runtime-environment
  - python-uv-dependencies
  covers_topics:
  - python.interpreter-resolution
  - python.venv
  - python.module-run
  - python.sys-path-intro
  - python.pyproject
  - python.uv-lock-sync
  - python.dependency-group
  - python.reproducible-environment
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Python 运行时、uv、虚拟环境与依赖

> 本章不教变量和 `if`，只建立一条可重复运行链。结束时，你应能回答：shell 找到哪一个 `python`，项目实际由哪一个解释器执行，包安装在哪个环境，`pyproject.toml` 与 `uv.lock` 各自表达什么，以及为何“我电脑能 import”不是项目证据。

## 1. Python 不是一个抽象的“软件图标”

日常说“Python”可能指：

- Python 语言规范；
- CPython 实现；
- 某个具体解释器可执行文件；
- 某个虚拟环境；
- 包管理工具；
- 一个项目及其依赖集合；
- IDE 选中的 interpreter。

这些对象不相同。`python3 --version` 只能说明当前 shell 按 PATH 找到的命令版本，不能证明 IDE、`uv run`、定时任务或部署容器使用同一路径。

### 1.1 2026.2 的版本表面

本卷以 CPython 3.14 系列为教学表面。2026-07-24 查询 Python 官方发布页时，3.14.6 已取代较早的 3.14.3 补丁。补丁版本会继续变化，所以项目写 `requires-python = ">=3.14,<3.15"` 或团队选定的更具体范围，并在锁定/部署证据中记录实际 patch。

不要把“3.14 最新补丁”理解成项目可以每天无审查漂移。安全修复值得升级，但升级仍要更新锁文件、运行测试并保留回滚点。

### 1.2 CPython、PyPy 与实现边界

本教材默认 CPython。其他实现可能兼容大部分语言，但 C 扩展、性能、垃圾回收和发布节奏可能不同。项目若声称支持其他实现，需要实际矩阵，不可由“都是 Python”推断。

## 2. shell 如何解析解释器

先保存现场：

```bash
echo "$SHELL"
type -a python python3 uv
command -v python3
python3 --version
python3 -c 'import sys; print(sys.executable); print(sys.version)'
uv --version
```

`type -a` 展示同名命令候选和解析顺序；`command -v` 展示当前首选；`sys.executable` 是正在执行代码的解释器路径。三者结合比只看版本可靠。

macOS 可能同时存在：系统 Python、python.org 安装、Homebrew、pyenv/uv 管理版本、IDE 环境和项目 `.venv`。不要删除系统自带运行时，也不要在系统 Python 上用 sudo 安装项目包。

### 2.1 PATH 不等于虚拟环境

激活虚拟环境通常把 `.venv/bin` 放到 PATH 前面，并设置 `VIRTUAL_ENV`。它没有复制操作系统，也不是容器；只是让命令和包解析优先使用该目录。

```bash
echo "$VIRTUAL_ENV"
command -v python
python -c 'import sys; print(sys.prefix); print(sys.base_prefix)'
```

虚拟环境中 `sys.prefix` 通常指环境，`sys.base_prefix` 指基础解释器。两者不同是识别线索。

激活只是交互式便利，不是唯一方式。`uv run` 可以在项目环境中执行命令，无需让当前 shell 永久激活。

### 2.2 shell、IDE 与子进程

从 Dock 打开的 IDE 可能不继承终端 `.zshrc`。IDE 要显式选择项目 `.venv` interpreter。父进程环境传给子进程，子进程修改不会反向改变父 shell；这与 Java 环境调查中的规则一致。

CI、cron、launchd 不应依赖个人交互启动文件。使用绝对工具路径、项目命令和明确环境变量。

## 3. 虚拟环境解决什么

项目 A 需要包 X 1.x，项目 B 需要 X 2.x。若都装到全局 site-packages，就会冲突。虚拟环境为每个项目建立独立安装位置和命令入口。

它解决：

- 项目依赖隔离；
- 工具命令与解释器关联；
- 避免污染全局/系统环境。

它不自动解决：

- 依赖版本是否锁定；
- 操作系统库、CPU/GPU 驱动差异；
- Python patch 漂移；
- 环境变量和外部服务；
- 构建是否可重复。

所以 `.venv` 是可再生结果，不提交 Git；`pyproject.toml`、`uv.lock`、Python 版本合同才是输入。

### 3.1 标准 venv 与 uv 项目环境

标准库：

```bash
python3.14 -m venv .venv
source .venv/bin/activate
python -m pip --version
```

uv 项目通常由 `uv sync`/`uv run` 自动建立 `.venv`。两者的虚拟环境概念相同，管理工作流不同。本卷选择 uv 作为项目依赖与运行入口，但理解标准 venv 有助于诊断。

不要在 uv 管理项目里一边 `uv add`、一边随意 `pip install` 到 `.venv`。后者可能让环境出现未声明包，别人按锁文件无法复现。

## 4. 从空目录建立 uv 项目

先查看当前帮助，因为 uv 更新较快：

```bash
uv init --help
uv init factorycare_ai
cd factorycare_ai
```

截至 2026-07 的官方文档，默认 `uv init` 创建 application 项目；`--lib` 创建库模板。应用项目适合 Web 服务、脚本和 CLI。

典型结构：

```text
factorycare_ai/
├── .python-version   # 项目首选 Python 版本线索
├── pyproject.toml    # 项目元数据与直接依赖声明
├── uv.lock           # 跨平台解析结果，由 uv 管理
├── .venv/            # 本机可再生环境，不提交
├── README.md
└── main.py 或 src/<package>/
```

不同 uv 版本和模板会略有差别，以实际生成结果为准。

### 4.1 选择 Python

```bash
uv python list
uv python pin 3.14
uv run python -c 'import sys; print(sys.executable); print(sys.version)'
```

`uv python pin` 可写 `.python-version`，帮助选择解释器。它与 `pyproject.toml` 的 `requires-python` 职责不同：前者是本项目/工具的选择提示，后者是项目声明的兼容范围。

如果机器没有合适解释器，uv 可按配置下载管理版本。企业环境可能禁止自动下载，需要镜像/预装策略；把该选择记录在团队文档和 CI。

## 5. `pyproject.toml` 是项目声明

最小概念示例：

```toml
[project]
name = "factorycare-ai"
version = "0.1.0"
description = "FactoryCare AI helper service"
requires-python = ">=3.14,<3.15"
dependencies = []

[dependency-groups]
dev = []
```

`[project]` 基于 Python 打包标准表达名称、版本、Python 范围与运行依赖。开发依赖组用于测试、lint、类型检查等不属于运行时的工具。

### 5.1 直接依赖与传递依赖

你在代码中直接 import/依赖的第三方包，应成为直接依赖。这个包自己依赖的其他包是传递依赖，由解析器锁定。不要把 `pip freeze` 的全部环境列表不加区分地当项目声明；它可能含无关全局包且失去意图。

### 5.2 版本范围与锁文件不是二选一

`pyproject.toml` 表达允许范围与项目意图；`uv.lock` 记录解析出的确切版本、来源、哈希和平台条件。库发布通常需要合理兼容范围；应用部署需要精确可复现解析。两者一起使用。

### 5.3 不手改 uv.lock

官方文档明确把 `uv.lock` 视为由 uv 管理的、可读 TOML 锁文件。需要变化时修改项目声明并用 uv 命令更新，提交差异。手改可能破坏内部一致性。

## 6. add、remove、lock、sync 与 run

### 6.1 添加依赖

```bash
uv add httpx
uv add --dev pytest
```

当前命令具体选项以 `uv add --help` 为准。操作通常同时更新 `pyproject.toml`、`uv.lock` 和项目环境。审查时看直接声明为何变化、锁文件引入哪些传递包、来源是否可信。

移除：

```bash
uv remove httpx
```

### 6.2 lock

```bash
uv lock
uv lock --check
```

`uv lock` 创建或更新解析结果；已有锁文件会作为偏好，不会只因为仓库出现新版本就自动升级。`--upgrade` 或 `--upgrade-package` 才显式升级，仍受声明约束。

`uv lock --check` 适合 CI：若锁文件与项目元数据不一致，失败而非悄悄改仓库。

### 6.3 sync

```bash
uv sync
uv sync --locked
```

官方 2026 文档说明，`uv sync` 默认对项目环境进行 exact sync，会移除锁文件之外的多余包；这有助于发现手工污染。`--locked` 要求锁文件最新，否则失败。

不要在 CI 中让 `sync` 无审查更新 lock。使用 `uv lock --check`、`uv sync --locked`，并把锁文件更新留给独立依赖升级变更。

### 6.4 run

```bash
uv run python -c 'import sys; print(sys.executable)'
uv run python -m factorycare_ai
uv run pytest
```

`uv run` 在项目环境执行，并会按默认行为检查锁与环境、必要时同步。官方文档还区分 `--locked`、`--frozen`、`--no-sync` 等；不要凭名字猜：

- `--locked`：锁必须与元数据最新，不允许更新；
- `--frozen`：使用锁但不检查其是否与项目声明最新；
- `--no-sync`：不同步环境，并隐含更严格的冻结语义；
- 具体组合以当前 CLI 文档为准。

生产/CI 要优先失败而不是偷偷修正漂移。

## 7. 依赖组、可选依赖和工具

### 7.1 开发依赖组

PEP 735 dependency groups 用于开发、测试、文档等环境集合。uv 对 `dev` 组有默认同步行为，并提供 `--no-dev`、`--group`、`--only-group` 等选择。

不要把 pytest、ruff 等都放进运行时 dependencies，否则发布服务带入不必要工具和攻击面。也不要把运行时实际 import 的包只放 dev，部署时会缺失。

### 7.2 optional dependencies / extras

`[project.optional-dependencies]` 表达项目对使用者公开的可选功能，如 `postgres`、`gpu`。它与内部开发组不同。是否使用 extras 取决于发布/消费合同。

### 7.3 uvx / tool run

一次性工具可以通过隔离入口运行，避免污染项目依赖。但关键质量工具仍应声明版本并进入锁/CI，以防不同开发者用不同规则。

## 8. 模块运行与 `sys.path` 入门

### 8.1 运行文件与运行模块

```bash
uv run python path/to/script.py
uv run python -m factorycare_ai.cli
```

运行文件时，脚本目录会影响导入搜索；`-m` 按模块名从当前环境/路径解析，并正确建立包上下文。项目内部包入口通常优先 `python -m package.module` 或 pyproject 声明的 console script，而不是到处修改 `sys.path`。

### 8.2 `sys.path` 从哪里来

它大致受入口位置、标准库、site-packages、环境和 `PYTHONPATH` 等影响。打印取证：

```bash
uv run python -c 'import sys; print("\n".join(sys.path))'
```

不要把 `sys.path.append('/Users/me/project')` 当正式修复。它把本机绝对路径写进代码，隐藏项目没有正确安装/组织的问题。

### 8.3 当前目录同名遮蔽

若项目里建了 `json.py`、`typing.py` 或与第三方包同名文件，可能遮蔽真正模块。取证：

```bash
uv run python -c 'import json; print(json.__file__)'
```

第一条可信证据是实际 `__file__`，不是“我明明安装了”。重命名冲突文件并清理相应缓存后重跑。

## 9. 包来源与供应链

依赖不只有名称和版本，还有来源：PyPI、私有索引、Git、URL、本地 workspace。供应链合同包括：

- 允许的索引与 TLS；
- 包名防 typo-squatting；
- lock 中的来源和哈希；
- 凭证不写入仓库；
- 升级审查、漏洞扫描、许可证；
- 构建产物和 SBOM（发布章深化）。

不要为了绕过证书错误使用不安全 host 参数。它关闭验证并暴露中间人风险；应修复 CA、代理或内部索引配置。

uv 当前支持导出 requirements、标准化 `pylock.toml` 和 CycloneDX 等格式，但导出是互操作/发布输入，不应反向替代项目主锁文件，除非团队明确迁移工作流。

## 10. 可重复环境不等于复制 `.venv`

`.venv` 包含绝对路径、平台相关二进制与解释器链接，复制到另一机器可能失效。正确重建：

```bash
rm -rf .venv  # 仅删除确认可再生的项目环境
uv sync --locked
uv run python -m factorycare_ai
```

删除前确认当前目录和环境不是共享重要数据。正常验证不必每次删除；干净重建用于发布前或怀疑环境污染时。

可重复证据至少记录：

- OS/架构；
- uv 路径与版本；
- 实际 Python executable/version；
- `sys.prefix` / 环境位置；
- `pyproject.toml` 与 `uv.lock` commit/digest；
- `uv lock --check` / sync / run 退出码；
- 外部系统依赖与未验证平台。

## 11. IDE 配置

VS Code/PyCharm/IDEA 要选项目 `.venv/bin/python`。IDE 显示可 import 但终端失败，或反之，通常是解释器不同。

诊断不要先重装插件：

1. IDE 显示 interpreter path；
2. IDE 内终端/运行配置打印 `sys.executable`；
3. shell 执行 `uv run python` 打印同一信息；
4. 比较工作目录、环境变量和模块入口。

Jupyter kernel 也是独立进程，必须注册/选择项目环境；笔记本顶部打印版本与路径。否则“Notebook 能 import”可能来自另一个 kernel。

## 12. CI 合同

一个简化 CI 顺序：

```text
检出固定 commit
-> 安装/选择固定 uv
-> 提供兼容 Python 3.14
-> uv lock --check
-> uv sync --locked
-> uv run --locked python -m ... / test / lint
-> 生成制品
```

缓存 uv 下载与环境可提速，但 cache key 要包含 OS、架构、Python、uv、lock digest。缓存命中不应跳过 lock 检查。

CI 失败时区分：

- 找不到解释器；
- requires-python 不匹配；
- lock 过期；
- 解析/下载失败；
- wheel 构建/系统库失败；
- import/测试失败。

每层修复不同。

## 13. FactoryCare 的 Python 边界

FactoryCare Python 侧负责 AI/数据派生能力，不成为工单业务事实所有者。项目可以叫 `factorycare-ai`，但公开合同由 Java 服务编排/授权。Python 依赖重、更新快，锁定与隔离尤其重要。

建议初始：

```text
Python 3.14.x
uv 管理项目与锁
src/factorycare_ai/ 包布局
tests/ 自动测试
运行依赖与 dev 组分离
uv.lock 提交
.venv 不提交
```

机器当前可能已有 Python 3.14.3，而官方已发布更高 patch。教材资产默认使用标准库、尽量兼容 3.14 系列；正式项目升级到团队选定 patch 后重新 lock/test，不在正文声称本机已验证 3.14.6。

## 14. 故障案例

### 14.1 `python` 与 `uv run python` 不同

症状：直接 `python` import 失败，`uv run python` 成功，或相反。

首个证据：两边 `sys.executable`、`sys.prefix`、包 `__file__`。

修复：项目命令统一经 uv，IDE 指向项目环境；不要把包装到全局作为修复。

### 14.2 `pyproject` 改了但 lock 未更新

症状：CI `uv lock --check`/`uv sync --locked` 失败。

首个证据：错误明确指出 lock 与 metadata 不一致。

修复：在依赖变更分支运行正规 `uv add/remove/lock`，审查并提交两份文件；CI 重跑。不要在 CI 取消 locked 让它静默改 lock。

### 14.3 “明明没声明也能 import”

症状：本机绿，干净环境失败。

原因：手工 pip、错误激活环境或传递依赖偶然暴露。

证据：`uv sync` exact 后消失；检查直接依赖声明与 import 来源。

修复：将真正直接依赖用 `uv add` 声明，干净同步重跑。

### 14.4 解释器不满足 `requires-python`

症状：解析器拒绝项目或包。

证据：实际 `sys.version` 与 pyproject 范围。

修复：选择兼容解释器；若要扩大范围，必须运行版本矩阵而不是只改文本。

### 14.5 当前目录遮蔽包

症状：导入对象缺属性、堆栈指向项目同名文件。

证据：模块 `__file__`。

修复：重命名本地文件，移除错误缓存，按模块入口重跑。

## 15. 实验：从空目录重建

### 15.1 建立证据目录

```bash
mkdir -p evidence/python-runtime
{
  date -Iseconds
  uname -m
  type -a python python3 uv
  uv --version
  uv run python -c 'import sys; print(sys.executable); print(sys.version); print(sys.prefix); print(sys.base_prefix)'
} > evidence/python-runtime/environment.txt 2>&1
```

公开前脱敏用户名、私有索引、token 和绝对路径中敏感部分。

### 15.2 创建与验证

```bash
uv init factorycare_ai_lab
cd factorycare_ai_lab
uv python pin 3.14
uv add --dev pytest
uv lock --check
uv sync --locked
uv run --locked python -c 'import sys; print(sys.executable)'
```

然后删除确认可再生的 `.venv`，只凭仓库输入重建，比较解释器、包树和退出码。

### 15.3 故障注入

任选：

- 直接用全局 python 运行，记录 import/path 差异；
- 修改 `pyproject.toml` 但不更新 lock，证明 `--locked` 失败；
- 手工安装未声明包，再 exact sync，观察被移除；
- 建同名 `json.py`，用 `__file__` 定位遮蔽，随后恢复。

保存“预测—失败—首证据—最小修复—原命令重跑”。

## 16. 自测与参考答案

1. **虚拟环境是否等于依赖锁？** 否，它是安装位置；锁文件才记录解析结果。
2. **为何不提交 `.venv`？** 它是平台/路径相关可再生结果，体积大且不可可靠复制。
3. **pyproject 与 uv.lock 区别？** 前者表达项目意图/允许范围，后者记录具体解析。
4. **为何应用提交 uv.lock？** 让团队、CI、部署使用可复现版本与来源。
5. **`uv run` 是否必须先 activate？** 不必，它可直接在项目环境执行。
6. **`--locked` 的价值？** 锁过期时失败而不是静默更新。
7. **`python file.py` 与 `python -m package.module` 有何边界？** 入口与包上下文/sys.path 不同，项目包更适合模块入口。
8. **如何证明 import 来源？** 打印模块 `__file__`、解释器路径和 sys.path。
9. **开发依赖为何不放运行 dependencies？** 减少部署体积和攻击面，保持职责。
10. **本章越界反例？** 在这里详细教授列表、类、FastAPI 或 PyTorch；本章只建立运行链。

## 17. 章节验收清单

- [ ] 能区分语言、CPython、解释器、虚拟环境、包和项目。
- [ ] 能用 `type -a`、`sys.executable`、prefix 查明真实运行时。
- [ ] 能解释激活只是 PATH 便利，`uv run` 可不激活执行。
- [ ] 能从空目录 `uv init`、pin、add、lock、sync、run。
- [ ] 能区分 pyproject、uv.lock、.python-version 与 .venv。
- [ ] 能正确使用运行依赖、dependency group 和 optional extra。
- [ ] 能用模块 `__file__` 与 sys.path 定位导入漂移。
- [ ] 能在 CI 用 lock check / locked sync 阻止静默漂移。
- [ ] 能完成一次干净环境重建和故障注入。
- [ ] 对未测试的 Python patch/OS/架构明确写未验证。

## 18. 官方资料与更新检查

- Python 3.14 文档：<https://docs.python.org/3.14/>
- Python 3.14 发布：<https://www.python.org/downloads/>
- `venv`：<https://docs.python.org/3.14/library/venv.html>
- 命令行与 `-m`：<https://docs.python.org/3.14/using/cmdline.html>
- uv 项目：<https://docs.astral.sh/uv/concepts/projects/>
- uv locking/sync：<https://docs.astral.sh/uv/concepts/projects/sync/>
- uv CLI：<https://docs.astral.sh/uv/reference/cli/>

资料核对日期：2026-07-24。Python patch、uv 命令和锁格式会变化；解释器取证、环境隔离、声明与解析分离、干净重建和失败优先是稳定核心。
