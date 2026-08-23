# P3-B1：Java 零基础黄金样章批次评审

## 批次范围

- 日期：2026-07-16
- 工作树：`codex/encyclopedia-rebuild`
- 章节：4 章，81,585 个 Unicode 字符（含元数据与代码块）
  - `ch.java.platform-toolchain`：14,983
  - `ch.java.program-structure`：23,135
  - `ch.java.values-variables-types`：17,834
  - `ch.java.expressions-conversions`：25,633
- 配套工件：`examples/encyclopedia/`、`labs/encyclopedia/`、`exercises/encyclopedia/`、`solutions-private/encyclopedia/` 中对应的四个章节目录。
- 生命周期：版本状态从 `architecture` 进入 `authoring`；4 章为 `drafting`，其余 251 章仍为 `planned`。

本记录只评审教材批次，不是用户学习证据。`PROGRESS.md` 未修改，当前学习周仍由原进度系统独立判定。

## 自动验证

最终冻结工作树实际通过：

```text
ruby scripts/generate-curriculum.rb --check
ruby scripts/validate-encyclopedia.rb --quiet
ruby scripts/validate-encyclopedia.rb --check-generated --quiet
ruby scripts/build-book.rb --check
ruby -Itests tests/curriculum/test_validate_catalog.rb
ruby -Itests tests/encyclopedia/test_build_book_v2.rb
ruby -Itests tests/source_inventory/test_build_source_inventory.rb
ruby -Itests tests/encyclopedia/test_encyclopedia_security.rb
ruby scripts/validate-learning-assets.rb
git diff --check
git diff --exit-code -- PROGRESS.md
```

结果：

- 目录编译器：29 runs / 97 assertions / 0 failures / 0 errors；
- 构建器：6 runs / 64 assertions / 0 failures / 0 errors；
- 来源清单：26 runs / 408 assertions / 0 failures / 0 errors；
- 安全对抗：41 runs / 265 assertions / 0 failures / 0 errors；
- 学习资产：2,354 checks，通过；
- 百科校验：255 章，251 `planned`、4 `drafting`，生成物与规范字节级一致；
- 站点骨架：5 个受控生成文件，`BOOK BUILD CHECK OK`；
- 学习进度：无差异。

## 代码与实验复现

- 工具链章：Temurin 25.0.3 下正常编译/运行、class major 69、精确输出、非法 release 和错误 classpath 均以预期阶段失败；分别伪造 `java 21 + javac 25` 与 `java 25 + javac 21` 时脚本退出 2。
- 程序结构章：正例精确两行；非法标识符、缺分号、括号不配对、package/sourcepath 不一致四类故障均命中精确诊断；私有解与四个临时最小修复均复跑通过。
- 值与类型章：私有 lab 解经 Maven 构建后与固定输出逐字一致；四类编译故障逐个验证文件名与错误类别；`java`、`javac`、Maven runtime 都要求 JDK 25，混用 JDK 26 时退出 2。公开 starter 默认未完成时输出比较失败，这是练习预言机的预期行为。
- 表达式章：17 行正例拒绝缺行或多行；三个运行故障验证精确异常消息和自身 `main` 栈帧；窄化编译故障验证类别与文件位置；实验 8 个断言、溢出负测、金额守恒和私有答案均通过。

上述运行证据来自 macOS arm64、Eclipse Temurin 25.0.3。精确 `ArithmeticException` 消息是该发行版的当前实测预言机；Java API 的跨发行版稳定契约只保证异常类型。

## 七维评审

| 维度 | 结论 | 证据与边界 |
|---|---|---|
| 技术正确性 | PASS | 定义、阶段、类型转换、溢出与错误边界经两组独立审稿人复核；官方 JLS/JVMS/API 来源直接支持版本敏感结论。 |
| 零基础教学 | PASS_WITH_FOLLOW_UP | 具备预测、解释、复制运行支架、独立构建、故障、需求变更和关闭 AI 复述；尚无真实零基础读者试读数据。 |
| 代码与可重复性 | PASS_WITH_FOLLOW_UP | 所有正例、故障、实验和私有答案在目标环境复跑；尚未覆盖 Windows、Linux 和另一 JDK 25 发行版。 |
| 安全、隐私与可靠性 | PASS | 无凭据与真实敏感数据；说明了输出、日志、金额单位、AI 审查和失败预言机边界。 |
| 可访问性与包容性 | PASS | 本批无 UI 或图片；状态均有文字证据，不依赖颜色；表格和代码块有上下文。 |
| 版本与来源 | PASS_WITH_FOLLOW_UP | JDK 25 目标、复核日期和一手官方来源齐全；精确诊断文本需在其他发行版重新确认。 |
| 出版与导航 | PASS_WITH_FOLLOW_UP | ID、链接、目录、路线、搜索索引和站点数据构建通过；实际 HTML/PDF/EPUB 版式及键盘/屏幕阅读器检查尚未完成。 |

## 已关闭问题

- 修正目录生成物漂移，并在最后一次规范修改后按 `generate --write → build-book → 两类 check` 冻结复验；
- 同时校验 `java`、`javac` 和适用处的 Maven runtime，拒绝混用 JDK；
- 把 `static`、`null`、`Math.*Exact`、`Integer.MIN_VALUE` 和 `assert` 登记为 `copy-run-only` 借用支架，且不写入本章 outcomes；
- 消除值与类型章中 `byte`/`short` 带来的隐藏转换前置；
- 把 raw `javac` 定位统一表述为文件、行号和插入符，而不是保证数字列；
- 将失败脚本从“任意非零”收紧为精确错误类别、文件位置、异常和输出行数；
- 修正程序结构实验的输出契约、UTF-8 说明和工具链实验 `work/` 忽略规则；
- 让迁移生命周期测试自行构造一致的 ready fixture，不继承真实仓库的后续 authoring 状态。

## 延期问题与未验证项

- P3 出版负责人：后续 P3 渲染批次补真实 HTML/PDF/EPUB 结果、分页/代码块/表格人工检查、键盘和屏幕阅读器检查；在此之前不能宣布 P3 完成。
- 教学验证负责人：找到真实零基础读者完成 20—30 分钟试读、命令复现和 120 秒复述，并记录卡点；当前自动化不能替代该证据。
- 平台验证负责人：补 Windows、Linux 和至少另一 JDK 25 发行版；当前只确认 macOS arm64 / Temurin 25.0.3。
- 四章仍为 `drafting`，没有提升为 `review` 或 `verified`；没有更新用户学习进度。

## 结论

**批次结论：`PASS_WITH_FOLLOW_UP`，阻断项 0。** 四章可作为后续正文生产的黄金样章，但 P3 阶段尚未完成：实际出版渲染和真实零基础读者验证仍缺证据。

## P3-R0 决策附录（2026-07-16）

用户已确认采用集成审计的全部推荐，详见 [`P3-R0-DECISIONS.md`](../P3-R0-DECISIONS.md)。本附录不追溯改变 P3-B1 的 `PASS_WITH_FOLLOW_UP` 结论，也不把尚未产生的证据写成已完成。

- P3 终点：四章完成七维评审、正式 HTML/EPUB/PDF 渲染和至少一轮编程零基础读者试读后进入 `review`；参与者、任务、允许提示和复测遵循 P3-R0 决策；
- 章节代码/JDK 已验证基线为 macOS arm64 + Temurin 25.0.3；正式出版构建仅为 `smoke_observed`，浏览器/阅读器/辅助技术为 `not_evaluated`；
- Windows、Linux、其他 JDK 25 发行版和其他阅读系统登记为 P4 follow-up，不是 P3 blocker，也不得写成已验证；
- P3 完成不等于 `verified` 或公开发布；七个 planned 基础前置及 Java 草稿链闭合后才能晋升；
- 出版管线采用 Ruby 门禁 + canonical Pandoc JSON AST + WeasyPrint；
- PDF 先追求字节一致；失败时只保存同一固定环境下的语义与版式回归证据，并明确它不是 reproducible build；
- 四章晋升 `review` 前必须完成 P2 公共输入与 publication manifest 摘要语义迁移；
- `review/verified` 必须有显式公共工件、verification manifest 和统一 Runner 证据；
- 开发权威仓保持私有；若需公开源码，使用不携带 private Git 历史的新公共发行仓；
- 当前四章继续保持 `drafting`，`PROGRESS.md` 不变。
