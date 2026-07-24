# P9 全局技术审计与收口记录（2026-07-24）

## 结论

- **自动化技术基线：`PASS_WITH_FOLLOW_UP`**。目录、生成、路线、先修、兼容入口、状态合同、公开/私有边界、出版候选、黄金样章验证和章节端点已完成本轮机器检查与回修。
- **正式 P9：尚未完成**。255 章仍保持 `drafting`，没有自动晋升为 `review` 或 `verified`，也没有公开发布。真实零基础读者试读、人工版式与辅助技术评估、独立环境复现，以及剩余 251 章的正式 verification manifest 仍缺少不能由 AI 或自动化替代的证据。
- **可以开始学习**。默认学习入口已切到权威百科；Week 00—48 只作为进度与训练兼容层，不再维护第二份正文。
- `PROGRESS.md` 未被本轮修改；课程建设结果没有冒充用户学习进度。

这里的 `PASS_WITH_FOLLOW_UP` 只表示“当前声明范围内的自动化技术基线通过”，不表示内容真理、教学效果、WCAG、EPUB Accessibility、PDF/UA、跨平台可复现或正式发行验收通过。

## 目标、范围与完成标准

本轮承接 P3—P8 延期到 P9 的机器可执行工作，目标是：

1. 让 16 卷、255 章、四条路线、先修关系和学习入口只有一个权威来源；
2. 检查每章正文与 example、exercise、lab、private solution 的一一对应；
3. 检查命令、测试、链接、版本、安全、私有答案和 FactoryCare 状态合同；
4. 扫描遗漏、长段落重复、近似重复、路线偏移和技术栈偏移；
5. 生成可重复的 HTML、EPUB、PDF 内部审查候选，并保持发布边界 fail-closed；
6. 建立正式 verification manifest 的 schema、Runner、覆盖硬门和原子证据写入；
7. 完成默认入口迁移、兼容说明、回滚说明和全仓回归。

完成标准明确排除：伪造真人试读、把 AI 视觉抽查称为人工版式验收、把标签存在称为无障碍合规、把同机双构建称为 reproducible build，以及自动猜测 251 章的测试预言后冒充人工确认的 manifest。

## 权威结构与规模

| 项目 | 结果 |
| --- | ---: |
| 分卷 | 16 |
| 权威章节 | 255 |
| 章节正文字符总数 | 4,034,617 |
| 最短章节 | `ch.ml.preprocessing-features`，11,997 字符 |
| 最长章节 | `ch.java.expressions-conversions`，25,900 字符 |
| 少于 10,000 字符的章节 | 0 |
| 能力 | 94 |
| 硬先修边 | 393 |
| 加速模块 | 48，ID 为 `m01`—`m48` |
| FactoryCare 阶段 | 8 |
| 版本注册项 | 62 |
| 章节生命周期 | 255 `drafting`；0 `review`；0 `verified` |

16 卷章节数分别为：

```text
00 15  01 11  02 12  03 18
04 17  05 18  06 19  07 13
08 18  09 15  10 12  11 19
12 19  13 16  14 16  15 17
```

## 路线与先修审计

路线审计递归统计 `chapter_ids` 和全部 `*_chapter_ids`；参考路线按其真实模型 `chapter_index` 的键统计，避免把映射误报为 0。

| 路线 | 原始引用 | 唯一章节 | 目录覆盖 | 无效 ID |
| --- | ---: | ---: | ---: | ---: |
| 零基础 | 255 | 255 | 100% | 0 |
| 48 模块加速 | 4,697 | 255 | 100% | 0 |
| FactoryCare 项目 | 781 | 205 | 80.39% | 0 |
| 参考索引 | 255 个 `chapter_index` 键 | 255 | 100% | 0 |

FactoryCare 路线在 schema 中明确为 `selective`，205/255 是设计结果，不是缺章。加速路线的重复引用来自 48 个模块中的 anchor、primary、supporting 和展开后的前置闭包，不是 4,697 个不同章节。

先修同步结果：255 章均有“学习前检查”；4 个根章节无需编程前置；393 条边全部指向存在的权威章节。先修图无无效边、无自环、无环，拓扑遍历覆盖 255/255。

## 默认学习入口与兼容迁移

采用长期维护优先的薄适配方案：

- `book/`、`curriculum/catalog.yml` 和 `curriculum/gates.yml` 是教材权威；
- `curriculum/compatibility/legacy-weeks.yml` 显式映射 Week 00—48；
- 49 个周页面和索引由同一脚本确定性生成；
- Week 00—08 的 `concepts.md` 只链接权威章节；lab、assessment、answers、interview 保留为独立训练资产；
- 学习教练先读取真实进度与周适配页，再加载当前任务所需的最小权威章节。

迁移检查结果为 `weeks=49`、`concept-adapters=9`，学习教练 Skill 校验通过，进度探测仍正确识别 Week 00 为“进行中”、49 行、0 错误、0 警告。详细影响见 `P9-legacy-entry-migration.md`。

## FactoryCare 状态与架构边界

WorkOrder 统一使用 12 个 canonical 状态：

```text
CREATED, TRIAGED, ASSIGNED, ACCEPTED, IN_PROGRESS, PENDING_PARTS,
PENDING_APPROVAL, RESOLVED, VERIFIED, CLOSED, REOPENED, CANCELLED
```

- 状态守卫扫描 939 个相关文件，错误为 0；
- 简化教学状态机已明确命名为 `DemoTicket`，不再伪装为完整 WorkOrder；
- `COMPLETED` 只作为明确标注的 UI 展示分组：`VERIFIED | CLOSED -> COMPLETED`；
- Java 后端保持业务权威，Vue、uni-app、Flutter 只调用 Java 合同，Python/ML/LLM 保持派生能力边界；
- 没有新增 React、Next.js、Kafka、Kubernetes 或 Java 微服务规范章节。正文中的 React 只用于少量已有知识类比。

## 端点执行审计

每章固定四个端点，共 1,020 项：

| 角色 | 总数 | 合同 |
| --- | ---: | --- |
| example | 255 | 退出码 0 |
| exercise | 255 | 在两个全新副本中保持同一非零退出码与等价诊断行集合 |
| lab | 255 | 退出码 0 |
| private solution | 255 | 退出码 0，且不进入公共发布输入 |

最终总审计结果：**1,020/1,020 通过，失败 0**；四个角色分别为 255/255。安全摘要报告 SHA-256 为 `ee1fdb586de4a60e3f411b98a430a64f02a42b7d27f8162d584b6db900d7b087`。

审计器拒绝缺失、多重入口、不可执行文件和端点树中的符号链接；公开练习每次复制到新的临时目录，不借用上一次运行状态。诊断归一化只处理明确的临时根、进程地址、测试摘要时钟，以及 Dart/Flutter 工具输出中的临时工程名和 formatter 耗时；退出码、真实错误行和其他文件名不会被放宽。

本轮发现并回修了两类审计环境问题：

1. 61 个 pnpm 锁文件根先按锁文件摘要与 package manager 组合预热到全新隔离 store，再逐根执行 `--offline --frozen-lockfile --ignore-scripts`；61/61 通过；
2. Vite 三链实验在并发负载下可能超过原 5 秒就绪窗口；现在等待最多 15 秒，并在服务进程提前退出时立即失败，而不是无限重试或吞掉真实失败。

## 重复、遗漏与目标偏移

扫描先去除 front matter、生成的“学习前检查”、代码围栏和统一训练模板，再比较正文：

- 2,962 个长度至少 120 的可比较正文段落；
- 跨章精确长段落重复组为 0；
- 255 章均至少有一个长度不低于 80 的可比较正文段落；
- 章节级最高 7-gram TF-IDF cosine 为 0.1758；
- 章节级最高 7-gram Jaccard 为 0.0362；
- 没有章节对达到保守提示阈值 `cosine >= 0.35` 或 `Jaccard >= 0.10`。

最高的章节对集中在合理的相邻主题，例如 CORS/CSRF 与浏览器 origin/cookie/cache、Outbox 与消息交付、JWT resource server 与 OAuth2/OIDC、Flexbox 与 Grid。局部高相似段落主要来自 12 状态合同、ADR-0003、同一工具版本边界和 strict JSON Schema；它们保留为人工边界复核候选，机器没有自动删文。

结构扫描未发现技术栈目标偏移。机器结论不能证明每个概念语义绝对正确、没有任何遗漏或真人一定能区分相邻职责；因此校验器明确输出 `content_truth=not-asserted`。

## 正式 verification 合同

P9 D5 的 schema、路径/模式/私有边界、输入摘要、工具版本、固定命令、退出码、观察预言、完整输出增量和原子 evidence 写入已经实现。

- 已正式审查 manifest：4/255；
- recipes：12；锁定输入：42；
- 两次真实执行均通过，规范 evidence SHA-256 都为 `b7ceb895970196abe4c27ba4055f8cfd1d96336af5b21dbb3e2608dec37a0e95`；
- 其余 251 章已有 bootstrap candidate，覆盖 753 个公共端点；候选状态固定为 `bootstrap-observed-unreviewed`；
- `--require-complete` 和 coverage 命令按设计返回非零，报告 `missing_final_manifest_count=251`，没有把候选静默算作正式合同。

1,020 端点审计证明入口当前可执行，但不自动生成每章精确的输入闭包、工具合同、输出增量和人工确认预言，所以不能冒充 255 份 final manifest。

## HTML、EPUB 与 PDF 内部候选

`p3-gold` 仍是 4 个黄金样章的内部审查 profile，不是 255 章公开发行物。出版 plan 有 88 个显式输入，生成 9 个受控输出；私有答案、远程资源、未声明文件和本机绝对路径均被拒绝。

同一台 Mac、固定工具链、两个新 staging tree 连续构建的全部文件摘要相同。关键摘要：

| 工件 | SHA-256 |
| --- | --- |
| output manifest | `9a3573c206883ce08e74a91ef0e9f4b4460f97724e11d37ec0fcf773a640af95` |
| EPUB | `99006d488d4ef474d97698eb38e18e9c2982ed292f38b065baf7ada7d2a4ca5a` |
| PDF | `02fd4760782417b7b958296352a32eb9a0bd4aee7b4b488b96d84f87ade77b18` |
| HTML index | `d08b4ecaa1e41a84de49f52d71d5138bb99fb41813fb5b8bcd3d3606e98150b8` |

PDF 为 124 页、A4、PDF 1.7，`Tagged: yes`；字体均嵌入、子集化并带 Unicode 映射。EPUB ZIP 完整性检查通过，HTML 内链和固定输出集合检查通过。AI 仅抽查了 PDF 第 1、2、4、60、123、124 页，未见明显裁切、乱码或重复内部通知；这不是人工版式、阅读顺序或辅助技术验收。

确定性入口锁定 WeasyPrint 68.1 / pydyf 0.12.1，并只修正该版本带标签表头依赖进程对象地址的 ID。版本不匹配时 fail closed。同机双构建字节相同只称为**本机字节重复性证据**，不称为 reproducible build 或跨平台可复现。

## 版本与来源可达性

62 个版本注册来源在 2026-07-24 做了带重定向的只读可达性检查：24 个 HTTP 200、38 个 HTTP 206、失败 0。该检查只证明当时 URL 可访问，不证明页面语义、版本选择或正文事实仍然正确。

来源清单测试通过 26 个测试、399 个断言并有 1 个明确 skip：本机不存在可选的 pinned audit repositories，因此没有运行“双外部仓完整构建”场景。skip 不是通过证据，已保留为外部环境后续项。

## 自动化回归摘要

本轮已验证：

- curriculum 生成检查：255 章、16 卷、94 能力、48 模块、8 个 FactoryCare 阶段；
- 先修检查：255 章、4 根、393 边、0 漂移；
- 旧入口检查：49 周、9 个 concept adapters；
- book 生成检查：5 个既有站点文件字节一致；
- 百科校验：3 个 schema、255 `drafting`、62 版本项、939 个状态上下文、生成结果 byte-exact；
- 学习资产：1,369 个 Markdown 文件、6,153 项检查；FactoryCare 设计 1,360 项检查、6 个事件 schema、2 份 OpenAPI；
- P9 新旧 Ruby 测试合计 190 个测试、10,056 个断言，0 failure、0 error；来源测试保留上述 1 个明确 skip；
- publication plan `--check` 在渲染前通过，随后实体连续构建两次且 11 个文件摘要完全相同；
- `git diff --check` 在提交前执行，临时构建与运行 evidence 不进入版本控制。

## 尚未完成的人工门

以下项目必须保持未验证，不能由本轮模型自审代替：

1. 至少一名真正编程零基础读者按固定任务完成导航、前置补救、复述、运行、修改、诊断，记录提示、卡点、误解、用时、修订与复测；
2. HTML、EPUB、PDF 在目标浏览器/阅读器中的人工版式、键盘、焦点、阅读顺序和读屏评估；
3. EPUBCheck、Ace、veraPDF 等完整机器门；当前本机没有这些 CLI；即使未来零错误也不能替代人工判断；
4. 独立执行方或另一平台按声明环境重建并核对摘要；
5. 对 251 个 bootstrap candidate 逐章确认输入闭包、命令、工具版本、预言和输出集合，再晋升为 final manifest；
6. 与真实读者分离的最终独立内容审查，特别是相邻安全、消息、ML 与 LLM 章节的职责边界。

在这些证据关闭前，正式 P9、章节晋升和公开发行必须保持未完成。

## 兼容折中、迁移与回滚

有意保留的兼容折中：

- 保留 Week 00—48 编号、进度行、阶段门和训练资产；只移除重复长讲义；
- 保留 Week 00—08 的 labs、assessment、answers、interview，因为它们不是正文副本；
- 保留既有 P2 五文件站点合同，黄金样章实体出版仍在被忽略的 sidecar 中；
- 旧周页面的段落锚点不再兼容，这是消除双正文的已披露破坏性影响。

迁移源是 `curriculum/compatibility/legacy-weeks.yml`。发生问题时应对最终 P9 提交执行完整 `git revert`，或从标签 `pre-encyclopedia-2026-07-16` 读取旧长页；不要只恢复单个旧页面，否则会重新形成两个真相来源。出版候选是可重建工件，回滚代码后重新生成，不依赖保留本机 `build/`。

## 明确非目标

- 不修改真实学习时长、成绩、完成日期或 Week 状态；
- 不发布公共网站、Release、软件包或私有答案；
- 不声称南京/南昌就业市场样本代表全部市场；
- 不安装或配置当前不学习的 Android/iOS 工具链；
- 不把 FactoryCare 改成微服务，不让 Python 取代 Java 业务权威；
- 不为了降低重复率删除必要的本地安全/状态合同提醒；
- 不把 AI 写出的代码、文件存在或一次绿灯当作用户已经掌握。
