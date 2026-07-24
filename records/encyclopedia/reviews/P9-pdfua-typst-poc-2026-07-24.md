# P9 PDF/UA 替代渲染器 PoC（2026-07-24）

## 结论

Java 语言卷的小样满足迁移触发条件：Pandoc 3.9.0.2 将 P8 的最终分卷 JSON AST
写为 Typst，Typst 0.15.1 以 `ua-1` 和固定 creation timestamp 连续生成两份逐字节
相同的 A4 PDF；veraPDF 1.30.0 的 PDF/UA-1 profile 报告 106/106 条规则、
942454/942454 个检查通过，失败规则和失败检查均为 0。

因此 P8 完整出版的 PDF 分支迁移到 Typst。P3 黄金样章仍保持冻结的 WeasyPrint
分支，避免把已存在的 v1 样章合同静默改写。迁移不改变 HTML、EPUB、打印 HTML、
章节状态或公开发行边界。

## 官方能力依据

- Typst 官方 PDF 文档说明 CLI 可用 `--pdf-standard ua-1`，并强调仍有无法自动检查的
  PDF/UA 规则：<https://typst.app/docs/reference/pdf/>；
- Typst 官方无障碍指南说明 PDF/UA-1、语义元素、语言、标题以及机器和人工测试的边界：
  <https://typst.app/docs/guides/accessibility/>；
- Typst 0.15.1 是本次实际锁定版本：<https://typst.app/docs/changelog/0.15.1/>；
- Pandoc 官方手册将 Typst 列为 PDF engine，并支持 `-t typst`：
  <https://pandoc.org/MANUAL.html>。

这些来源支持工具能力选择，不证明本教材工件天然合规。最终结论仍以本仓冻结输入、
真实构建、veraPDF 报告和人工辅助技术检查为准。

## 固定输入与命令语义

- 输入：`build/publication/internal-complete/ast/volumes/volume-01.json`；
- Pandoc：3.9.0.2；Typst：0.15.1；veraPDF：1.30.0；
- 输出：PDF 1.7、Tagged、A4、152 页；
- PDF 标准：`ua-1`；纸张：A4；
- 创建时间：来自 P8 plan 的 `source_date_epoch`，不读取当前时钟；
- 网络策略：构建命令不需要远程资源，但本 PoC 未使用 OS 级网络隔离。

P8 canonical AST 同时给 chapter Div 和其首个语义 H1 相同 ID；Pandoc Typst writer 会
把两者都输出成 label，Typst 因重复 label 正确拒绝编译。适配器只清除生成包装 Div
的 ID，保留语义标题的 ID。Markdown 中没有 bibliography 的 `@Test` 等词可能被
Pandoc 解析为 `Cite`；适配器使用其已经存在的可见 inline fallback 还原字面文本。
适配前后 Link 与 Image 节点计数必须逐项相等，否则 fail-closed。

## 观察结果

| 项目 | 结果 |
| --- | --- |
| Typst 编译退出码 | 0 |
| 两次 PDF SHA-256 | `f2ed60b8dbd98eff01105803351e860b8acce0cb901c8e193fa0f45f66394855` |
| 两次 `cmp` | 逐字节相同 |
| veraPDF job | normal |
| PDF/UA-1 compliant | `true` |
| passed / failed rules | 106 / 0 |
| passed / failed checks | 942454 / 0 |
| Tagged | yes |
| Suspects | no |

临时 PoC 文件位于系统临时目录，不是持久证据包，也不纳入 Git。正式证据必须由独立
P9 无障碍审计器绑定最终 P8 plan、output manifest、工具身份和每个最终 PDF 摘要后
原子生成。

## 仍未证明

- 这只是单卷 PoC，不是整书和全部 16 卷的最终机器复核；
- veraPDF 机器通过不证明阅读顺序、替代文本质量、中文/代码朗读、表格导航、链接语义、
  放大重排或 VoiceOver/其他屏幕阅读器体验；
- 本机两次字节相同不等于跨平台 reproducible build；
- 本记录不把任何章节从 `drafting` 自动晋升，也不授权公开发布。

若全量迁移构建、P9 独立审计或人工专项检查出现不可接受回归，回滚方式是整体 revert
本次 P8 Typst 迁移，再从冻结计划重建 WeasyPrint 内部候选；不得删除链接、关闭标签或
放宽 veraPDF profile 来换取绿灯。
