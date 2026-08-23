# P9 卷 11–12 练习可达性修复记录（2026-07-24）

## 结论

AI 预审 F05 指出的 11 个“只有 heredoc / 固定红验证器、没有可编辑 starter”问题已修复。
每章现在都有公开可编辑输入、公开 README、独立行为 oracle，以及文件化的私有参考实现。

本记录是自动化修复与机器验证证据，不是独立人类复核、真实设备测试或发布批准。

## 退出码合同

- `41`：公开 starter 命中该章预先定义的 expected-red 行为合同；
- `0`：同一个公开验证器在临时副本中替换为私有参考实现后全部转绿；
- `43`：输入文件缺失、编译/导入失败或其他非预期/基础设施失败；
- 私有 `verify.sh`：参考实现直接验证为 `0`。

公开验证器不读取、不导入、不复制 `solutions-private/`；私有实现没有泄漏到公开目录。

## 逐章证据

| 章节 | 公开可编辑输入与 oracle | starter | 临时修复副本 | 缺失输入 | 私有实现 | 主要合同 |
|---|---|---:|---:|---:|---:|---|
| `ch.dart.collections-patterns` | `starter.dart`、`oracle.dart` | 41 | 0 | 43 | 0 | 顺序、重复、快照、只读边界 |
| `ch.dart.exceptions-resources` | `starter.dart`、`oracle.dart` | 41 | 0 | 43 | 0 | 成功值、异常类型/堆栈、两条路径关闭一次 |
| `ch.dart.oop-generics` | `starter.dart`、`oracle.dart` | 41 | 0 | 43 | 0 | 泛型保存/读取与实例状态隔离 |
| `ch.flutter.architecture-state` | `starter/lib/**`、`oracle.dart` | 41 | 0 | 43 | 0 | domain port、构造器注入、fake 替换、不可变状态、依赖方向 |
| `ch.flutter.device-apis` | `starter.dart`、`oracle.dart` | 41 | 0 | 43 | 0 | denied / deniedForever / unknown 映射、稳定诊断码、敏感信息脱敏 |
| `ch.flutter.navigation-forms` | `starter.dart`、`oracle.dart` | 41 | 0 | 43 | 0 | Saved / Cancelled 类型化结果及合同外输入 fail closed |
| `ch.flutter.network-storage-offline` | `starter.dart`、`oracle.dart` | 41 | 0 | 43 | 0 | 持久化、重启、重试复用幂等键且副作用一次 |
| `ch.flutter.release-monitoring` | `release.env`、`verify.sh` | 41 | 0 | 43 | 0 | 版本、build、commit、制品/符号哈希与监控 release 精确关联 |
| `ch.flutter.testing-performance` | `test-contract.env`、`verify.sh` | 41 | 0 | 43 | 0 | 精确 pump、golden 指纹、controller 释放、真实 profile 前置条件 |
| `ch.python.asyncio-cancellation` | `exercise.py`、`scripts/check.py` | 41 | 0 | 43 | 0 | 取消传播、所有者等待、清理一次、阻塞调用隔离、无遗留任务 |
| `ch.python.pydantic-validation` | `exercise.py`、`scripts/check.py` | 41 | 0 | 43 | 0 | strict、extra forbid、alias、范围、跨字段约束、schema |

## 验证方法

### 1. starter expected-red

逐章执行公开 `verify.sh`，11/11 均返回 `41`，且必须包含该章专用的
`EXPECTED_*_RED` 标记；普通编译失败不会被误记为 expected-red。

### 2. 同一检查器可达 green

将每个公开练习完整复制到 `mktemp -d`，只在临时副本中执行以下替换：

- Dart / Flutter 单文件题：`solution.dart -> starter.dart`；
- architecture 题：私有 `solution/` 内容覆盖临时 `starter/`；
- release / performance：`solution.env` 覆盖临时公开配置；
- Python：`solution.py -> exercise.py`。

随后仍运行临时副本中的原公开 `verify.sh`。11/11 均返回 `0`，证明不是固定红脚本，
也未污染仓库中的 starter。

### 3. 非预期失败映射

在另一组临时副本中移走各章唯一可编辑输入，再运行原公开验证器。11/11 均返回 `43`，
证明缺文件/导入/分析器故障不会伪装成学习者已命中 expected-red。

### 4. 私有参考与静态检查

- 11/11 私有 `verify.sh` 返回 `0`；
- 所有 Dart 参考与公开端点通过 `dart analyze --fatal-infos`；
- 所有 22 个公开/私有 shell 入口通过 `bash -n`；
- Python asyncio 行为检查通过本机 `python3`；
- Pydantic 通过 `uv run --isolated --with pydantic==2.13.4` 验证；
- 目标目录 `git diff --check` 通过；
- 公开目录搜索未发现 `solutions-private`、私有文件名或私有 PASS 标记引用。

## 明确未声称的事项

- device APIs 未在真实手机上调用权限插件；
- release 练习未生成真实签名、artifact、symbols 或监控事件；
- testing/performance 练习未生成真实 golden，也未在代表性设备上采集 profile；
- 本轮没有修改 `PROGRESS.md`、verification manifests、DoD、release validation 或 human attestation。

这些仍属于后续人工/设备/发布门，不由本次 F05 修复代替。
