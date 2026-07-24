# P9 全局技术审计与诚实收口记录（2026-07-24）

## 最终结论

**正式 P9 状态：`incomplete`。** 机器可执行的结构、路线、全端点、正式样章验证与内部出版候选已经形成可追溯证据，但人工教学、内容、链接、无障碍、独立构建和 251 章候选确认门仍未关闭。255 章继续保持 `drafting`；没有自动晋升章节状态，也没有公开发布。

当前自动化基线足以把教材投入实际学习使用；这只表示学习可以开始，不表示教材已经通过正式 P9。学习过程中产生的真实运行、修改、诊断、复述和项目证据仍需由学习者完成，不能用本轮机器报告代替。

| 分系统 | 状态 | 结论边界 |
| --- | --- | --- |
| curriculum / global | `passed` | 结构、路线、先修、重复与直接 HTTPS 来源存在性通过机器门；不证明内容真理或可学性 |
| version reachability | `passed` | 62/62 注册来源在检查时可达；可达不等于版本选择或正文事实正确 |
| live links | `needs-review` | 0 个硬失败，但 12 个唯一目标仍需人工判断 |
| endpoint audit | `passed-machine-observation` | 1,020/1,020 本机机器观察通过；不等于 255 份 final verification manifest |
| exercise / candidate | `observed-unreviewed` | 机器观察已生成，禁止在人工确认前晋升 |
| formal verification | `execution-succeeded-coverage-incomplete` | 4/255 份 final manifest 的 12 个 recipe 成功；仍缺 251 章 |
| P8 publication | `internal-candidate-built-not-released` | 255 章 HTML、EPUB、PDF 内部候选已构建；未通过正式发行门 |
| publication accessibility | `machine-findings-observed` | 278 个 HTML 自动扫描无 finding；18 份 EPUB 机器检查无 finding；18 份 PDF 仅 1 份通过 PDF/UA-1 机器验证 |
| formal P9 | `incomplete` | 人工门与独立门未关闭 |

`PROGRESS.md` 未被本轮修改；课程建设和机器运行结果没有冒充用户学习进度。

## 范围、口径与完成标准

本报告收口 P9 可由机器诚实验证的范围：16 卷 255 章的权威目录、四条路线、先修图、正文规模与重复扫描、来源与链接可达性、每章四类执行端点、正式 verification 合同覆盖、兼容学习入口和 P8 内部完整出版候选。

本报告明确不把以下证据互相替代：

- URL 可达性不替代来源权威性、引用蕴含关系或事实核对；
- endpoint 运行成功不替代人工确认的 final manifest；
- 候选观察不替代学习者证据或章节晋升；
- PDF 标签、字体嵌入和 AI 图像抽查不替代 WCAG、PDF/UA 或人工辅助技术评估；
- 同一台机器上的构建不替代独立执行方或跨平台可复现性。

因此，本轮的完成标准是“机器证据边界闭合且未夸大”，不是“正式发行完成”。

## 权威课程与全局结构

### 目录、卷、能力与生命周期

| 项目 | 当前值 |
| --- | ---: |
| 分卷 | 16 |
| 权威章节 | 255 |
| 能力 | 94 |
| 硬先修边 | 393 |
| 先修根节点 | 4 |
| 拓扑覆盖 | 255/255 |
| 章节生命周期 | 255 `drafting`、0 `review`、0 `verified` |

先修图没有无效边、自环或环。16 卷章节数依次为：

```text
00 15  01 11  02 12  03 18
04 17  05 18  06 19  07 13
08 18  09 15  10 12  11 19
12 19  13 16  14 16  15 17
```

### 路线

| 路线 | 原始引用 | 唯一章节 | 覆盖 | 无效 ID |
| --- | ---: | ---: | ---: | ---: |
| 零基础 | 255 | 255 | 100% | 0 |
| 48 模块加速 | 4,697 | 255 | 100% | 0 |
| FactoryCare 项目 | 781 | 205 | 80.39% | 0 |
| 参考索引 | 255 | 255 | 100% | 0 |

FactoryCare 路线在合同中明确为 `selective`，205/255 是设计结果；加速路线的 4,697 次引用包含 anchor、primary、supporting 与展开后的前置闭包，不代表 4,697 个不同章节。

### 正文规模与重复审计

“原始字符”按 catalog 引用的 Markdown 文件解码后计数，包含 front matter、代码与结构文本；“可比较正文”则移除 front matter、生成的学习前检查、代码围栏、HTML 注释、标题、列表、表格和来源 URL，再做 Unicode 规范化。两种口径不能混用。

| 口径 | 总字符 | 最短章 | 最长章 | 少于 10,000 字符 |
| --- | ---: | --- | --- | ---: |
| 原始 Markdown | 4,040,115 | `ch.ml.unsupervised-learning`：12,479 | `ch.java.expressions-conversions`：25,900 | 0 |
| 可比较正文 | 2,880,285 | `ch.dart.collections-patterns`：6,725 | `ch.architecture.observability-slo`：19,193 | 80 |

- 长度达到比较条件的可比较段落：7,104；
- 跨章精确长段落重复组：0；
- 7 字符 Unicode shingle 完整全配对：32,385/32,385，无采样；
- 最大 Jaccard：`0.050626761`；最大 containment：`0.100288739`，均来自 `ch.css.flexbox` 与 `ch.css.grid`；
- fail-closed 阈值：Jaccard `>= 0.32`，containment `>= 0.65`；违规对：0。

这些数字只支持“按当前规范化与阈值未发现精确或高相似复制”的结论，不支持原创性、事实正确性或人工内容质量声明。

## 来源、版本与链接

### 直接来源覆盖

255/255 章在排除 front matter、生成区、代码围栏和 HTML 注释后，至少存在一个可解析的直接 HTTPS URL。该门只证明语法存在性，不评价来源权威性、引用是否支撑正文或页面内容是否已变化。

冻结的 source inventory 测试结果为 **26 runs、408 assertions、0 failures、0 errors、0 skips**。

### 版本注册来源

`version-sources-2026-07-24.json` 的 SHA-256 为 `2a1ac370bb523fca1fa5d1ed9806afc67a29553222bf9400e0414780f2507fdb`。结果为 62/62 可达，其中 24 个 HTTP 200、38 个 HTTP 206、失败 0，分系统状态为 `passed`。

这只是 2026-07-24 的传输可达性观察，**不是真实性证据**；它不证明页面语义、版本选择、发布日期、兼容性或教材陈述正确。

后续的注册表 v2 迁移由 `version-registry-v2-2026-07-24.md` 单独记录。对应的 `version-sources-v2-2026-07-24.json` 绑定注册表原始字节 SHA-256 `bf683ed8c1bf9495c6015ef6ffa8527c1ef66b7089d0e427c210b3f52f944cd7`，逐条探测 71 个原子技术条目的 93 个来源：93/93 可达，33 个 HTTP 200、60 个 HTTP 206、失败 0。v1 数字保留为历史快照，不再代表当前注册表。

v2 结果仍然只属于网络可达性证据；审计程序禁止据此自动把 `provisional` 或 `conceptual` 提升为 `verified`，状态提升必须经过人工审查。

### 章节 Markdown 链接

`chapter-live-links-2026-07-24.json` 已在最终正文修订后重新执行，SHA-256 为 `b9065150462915cdaeed56e6d916362bcc24fdc98fde24e304d0289bd33a8526`。审计统计：

- Markdown HTTPS 出现次数：1,493；
- 唯一目标：1,138；
- 机器通过：1,126；
- 人工复核：12；
- 硬失败：0。

其中 5 个传输结果为 inconclusive，已包含在人工复核边界中。由于仍有 12 个唯一目标需要判断，分系统状态必须保持 `needs-review`，不能因为硬失败为 0 就改写为完全通过。该审计的冻结范围是 Markdown link/image destination；裸 HTTPS 文本与 autolink 尚未纳入此 v1 口径，不能把 1,138 个目标描述为章节全部 URL。

## 全端点机器观察

证据文件 `endpoint-audit-2026-07-24.json` 的 SHA-256 为：

```text
798d84b11d2dd60f98558dbcb7cbca3aeaa8cdec0a24fc5cadd503c95573ddec
```

结果为 1,020/1,020 通过、失败 0、基础设施失败 0：

| 角色 | 通过/总数 |
| --- | ---: |
| example | 255/255 |
| exercise | 255/255 |
| lab | 255/255 |
| private solution | 255/255 |

三个公共角色在两个独立 fresh copy 中运行；private solution 运行一次。exercise 要求同一精确非零退出码、规范化诊断行多重集和语义输出闭包一致。审计同时检查输入不被修改、非法 symlink、特殊文件、超时与进程组回收，但它是 clean-copy 约束，不是 OS 文件系统或网络沙箱。

该 JSON 是**可追溯的本机机器观察**：保存了运行策略、结果、缓存与工具边界，可以按文档命令再次执行，但不保证未来获得同环境重放或跨平台相同结果。endpoint 报告没有把完整审计器控制面与每个工具的运行时身份冻结成可重放合同，因此不能称为 reproducible evidence。

Dart/Flutter 在 fresh HOME 产生的 `home/.dartServer/**` 只从教材**语义输出比较**中排除；每次运行的原始 scratch 条目数、精确路径/类型集合摘要以及路径/字节摘要仍被保留。该排除不扩展到相邻名称、其他位置、symlink 或特殊文件。

pnpm runtime policy 记录的是审计启动时快照；pnpm store 与 Dart Pub 的有界内容清单另有 `post_run_matches_pre_run: true`。根代理在审计结束后又对 pnpm runtime、Docker policy 以及 pnpm/Dart 清单做了只读复核并与报告相符，但该复核没有写入 endpoint 报告控制面，所以不能据此升级为“可重放”声明。

## Exercise 合同观察与候选

### Exercise 报告

`exercise-contracts-2026-07-24.json`：

- SHA-256：`6c6fe073748c8862a0675cc06fb20e42d03ac8d1cb0f344baba5b96726b35522`；
- 状态：`observed-unreviewed`；证据类别：`machine-only-not-learner-evidence`；
- 255 章、510 次 fresh-copy 运行；
- `EXPECTED_RED` marker 存在 88 章、缺失 167 章；
- mechanical failure：0；
- 来源 endpoint 原始文件字节 SHA-256：`798d84b11d2dd60f98558dbcb7cbca3aeaa8cdec0a24fc5cadd503c95573ddec`。

marker 缺失是需要人工确认或规范化的机械缺口，不是 endpoint 执行失败。报告禁止在没有人工审查时晋升，也不计入用户学习证据。

### Candidate v2 报告

`observed-candidates-v2-2026-07-24.json`：

- SHA-256：`fa38e8c839f90e0d2d744767de55eee9a918cbe837e1a0da59143a7de5386212`；
- 251 个候选、753 个公共端点；
- 167 个候选 / 167 个端点带 mechanical gap；
- 15 个工具探针全部为 `observed`；
- 来源 endpoint 原始文件字节 SHA-256：`798d84b11d2dd60f98558dbcb7cbca3aeaa8cdec0a24fc5cadd503c95573ddec`。

工具探针是在 candidate 生成阶段另行执行的，**不是 endpoint 审计运行时快照**。这些候选固定为 `observed-unreviewed`，不能写入 `verification/manifests/`、不能自动变成 final，也不能用来声称学习者已完成练习。

## 正式 verification 合同

最后一次成功 evidence `verification/evidence/last-run/evidence.json` 的 SHA-256 为：

```text
5a815ef8aeee42ae600d4ae25a4179997696e0e265253fc1acc9c61ade76d81e
```

机器执行与独立只读复核得到：

- `result: succeeded`；
- final manifests：4/255；
- recipes：12；
- 锁定输入：42；
- 观察到的输出项：70；
- expected-nonzero recipe：4；
- 公共 Runner 控制面：11 项，digest 为 `aa736fdc3616c6d1d8ad9b0e1cd5e4e769b4cbbcb4ac949c60c88ac238f6d966`；
- 实际 Runner：Ruby 2.6.10p210；timeout 300 秒，TERM 后宽限 2 秒。

覆盖硬门按设计返回非零：255 章中只有 4 章具有 final manifest，`missing_final_manifest_count=251`。这不是 12 个现有 recipe 的执行失败，而是正式覆盖不完整；因此分系统只能写作 `execution-succeeded-coverage-incomplete`，正式 P9 不能完成。

独立的私有答案 Runner 只读 inventory check 已通过 255 章 / 255 recipe，但本轮完整 clean-copy 执行在首个受影响章节以 `E_PRIVATE_EXIT` fail closed，且没有写入 `verification/private-evidence/last-run/evidence.json`。原仓入口可返回 0，而 clean copy 未包含入口引用的公共验证器；静态检查共发现 16 个私有入口含父目录引用。因此这属于私有执行输入闭包缺陷，不是缓存基础设施失败，也不能描述为 255 份私有答案已经通过。

## P8 内部完整出版候选

### 冻结输入与 fail-closed 重建

最终 P8 v2 plan 包含 16 卷、255 章、4,127 个 Git 已跟踪公共 companion，共 4,401 个输入；private solution、未跟踪 companion、symlink、绝对输入路径和生成输入均为 0。plan 声明 345 个计划路径，其中一个是 output manifest 自身；最终 manifest 为避免自引用，只枚举其余 344 个输出工件。

本轮构建曾因公共 companion 在渲染过程中发生变化而以 `E_PLAN_STALE` fail closed，没有沿用过期产物。输入冻结后重新生成 plan 并完整重建，随后 plan check、output check 与结构检查通过。

| 工件 | SHA-256 |
| --- | --- |
| publication plan v2 | `d9206502d42d9e38e682a5dc7aeea10a24e3ce8180100a7a250233e7ebe1f574` |
| output manifest v2 | `ec0d96356648d07d47b62062c60c171e034be576d096060fe17aea1454a0ea3a` |
| whole HTML | `fa78042779a504344424c7be469d336b779464beff9a62112baef3bde7f2893e` |
| whole EPUB | `122bc21e25f70424c3d5655d6ed78a3762a81fc3e34e8cdedba49066fe33d660` |
| whole PDF | `c300851412bbef80549670f7dad3ffdfb9c44301255ebaa63a8b4dc4008cc071` |

output manifest 的 `build_status` 为 `succeeded`，枚举 344 个输出、记录 324 条命令；`build_input_digest` 为 `b8d804d0f59e86f11f449e456e9940abba1cdc2299285574e61775fdb0050c54`，`output_set_digest` 为 `a61e7f3b27dc8f4a295ddbfc2e6eb520c494b1f12f2ac498990ff1eda0c20364`。whole PDF 为 3,099 页、A4、PDF 1.7、`Tagged: yes`；检测到的字体均嵌入、子集化并带 Unicode 映射。whole EPUB 的 ZIP 完整性检查无错误。

AI 机器视觉重新抽查了当前 whole PDF 第 1、2、1,550、3,098、3,099 页，以及 volume 15 PDF 第 1、2 页；这些页面未观察到明显裁切、重叠、乱码或不可读字形。末页只有内部候选警示，大量留白是当前排版结果。这个结论只是有限页的 AI 图像检查，**不是人工版式、阅读顺序、键盘、焦点或读屏验收**。`Tagged: yes` 也不等于 PDF/UA 合规。

该工件的可见标识和 profile 均为内部候选，`visibility=internal`、`distribution_allowed=false`。它没有公开发布，也不得被描述成最终出版物。

### 出版无障碍机器观察

本轮重新对当前冻结字节执行原子机器检查，不沿用正文修订前的旧报告。单一进程先记录 18 份 PDF 及两份 output manifest 的 SHA-256/大小，执行 veraPDF，再次读取并要求扫描前后完全一致，同时逐项匹配 manifest；任何漂移都会使审计失败。规范化摘要 `build/factorycare-p9-verapdf-rescan-summary.json` 的 SHA-256 为 `c0710fb34dc64903fb1e4924aa73e87bea4cb6871915a795eb833dafdb7e7da1`，原始报告 SHA-256 为 `da4cd05f43e549a34d076754a401182b4069445d69fcfbf0362ab0021d13c2bb`。P8 的每个目标还与上述 output manifest 逐一比对，P3 PDF 则与其独立 output manifest 比对：

- axe-core 4.12.1：P8 273/273 个 HTML（255 章、16 卷、整书与索引）在固定 WCAG 2.0/2.1/2.2 A/AA tags 下为 0 violation、0 incomplete；P3 的 5/5 个 HTML 也为 0 violation、0 incomplete。自动零 finding 不是 WCAG 认证。
- EPUBCheck 5.3.0 `--failonwarnings`：P3 1 份 + P8 17 份，18/18 的 fatal/error/warning 均为 0。
- Ace 1.4.6：18/18 根 outcome 为 `pass`；严格只统计同时含 `earl:test` 与 `earl:result` 的叶子 assertion，failure 为 0。Ace 通过不是 EPUB Accessibility 认证。
- veraPDF 1.30.0 PDF/UA-1：18 个 job 均正常结束，其中 1 份合规、17 份不合规；共 17 条 failed rule、273 个 failed check，全部为 ISO 14289-1:2014 7.18.5 test 1：链接注释位于 `NonStruct`/artifact，而非 `Link` 标签。

为避免用版本号猜测，本轮另在临时环境使用 WeasyPrint 69.0 重建一份已知失败分卷。原 21 个链接失败未解除，反而新增 2 个 Apple Color Emoji 字形宽度失败，因此保留 WeasyPrint 68.1，不删除可点击链接来换取虚假绿灯。

上述原始工具报告目前位于被 Git 忽略的 `build/` 或临时目录；它们是当前机器观察，还不是经独立 schema、工具身份和脱敏规范化约束的可发行证据包。PDF/UA 机器失败、人工辅助技术验收与稳定证据管线都仍是 P9 未完成项。

## 学习入口、资产与真实进度边界

- `book/`、`curriculum/catalog.yml` 与 `curriculum/gates.yml` 保持权威；
- Week 00—48 共 49 个兼容周入口；Week 00—08 共 9 个 `concepts.md` 适配页；
- 最终学习资产校验：1,371 个 Markdown 文件、6,196 项检查；
- FactoryCare 设计校验：1,360 项检查、6 个事件 schema、2 份 OpenAPI；
- P9 在临时副本中使用 Playwright 1.60.0 + Chromium 148 真实运行登录→查询→打开工单路径，1/1 通过、无重试；两个 API 由 `page.route(...).fulfill(...)` stub，因此只证明真实浏览器中的前端交互，不证明真实后端、认证、数据库或部署联调；
- progress detector：Week 00 `进行中`、49 行、0 error、0 warning；
- `PROGRESS.md` 的 Git diff 为空，本轮没有写入学习时长、成绩、完成日期或周状态；
- `evidence/factorycare/**` 没有被预填。真实 FactoryCare 应由学习者在课程推进中实现并生成证据。

## 尚未关闭的人工与独立门

以下项目必须继续保持未验证：

1. 真正零基础读者按固定任务完成导航、前置补救、复述、运行、修改和诊断，并记录提示、卡点、误解、用时、修订与复测；
2. 与生成者分离的独立内容审查，核对事实、来源蕴含、概念边界和教学梯度；
3. 对 12 个 live-link 目标作人工判断；
4. 在目标浏览器和阅读器中完成人工版式、键盘、焦点、阅读顺序、深色主题、缩放/重排与 VoiceOver/读屏检查；
5. 修复并重新验证 PDF/UA 链接标签失败，完成人工辅助技术专项评估，并建立绑定工具身份与最终工件的稳定 P9 证据管线；
6. 由独立执行方或另一平台按声明环境重新构建并比对结果；
7. 对 251 个 candidate 逐章确认输入闭包、命令、工具版本、expected-red 预言和输出集合，再决定是否晋升为 final manifest。

任何一项都不能由本报告作者自审、AI 视觉或文件存在性代替。

学习者未来真实构建 FactoryCare、产生 `evidence/factorycare/**` 下的运行、修改、调试、验收和复述证据，属于学习执行门，**不是课程建设 P9 的阻断项**。学习开始前这些路径不存在是正确状态。

## 兼容折中、已知不兼容与回滚

有意保留的兼容面：

- Week 00—48 编号、49 行进度表、阶段门和独立训练资产继续保留；
- P2 既有五文件站点合同继续保留；
- `p3-gold` v1 黄金样章 profile 继续保留；
- P8 v2 internal-complete 与 v1 并行，不冒充 v1 的公开升级；
- `build/` 保持 Git 忽略、可从冻结输入重建；
- 不预填 FactoryCare 学习 evidence，也不把机器 evidence 合并进学习进度。

已披露的不兼容：旧周长讲义的段落锚点不再保证兼容。这是消除重复正文、回到单一权威来源的有意取舍；没有通过伪造兼容锚点掩盖该影响。

回滚应针对最终变更提交执行完整 `git revert`，再从相应冻结输入重建 `build/`。不要只恢复单个旧周页面，否则会重新形成两份正文真相来源。

## 明确非目标

- 不公开发布 HTML、EPUB、PDF、网站、Release、软件包或私有答案；
- 不把 255 章从 `drafting` 晋升，不把 formal P9 标为完成；
- 不自动晋升 251 个 candidate，也不把机器报告当作学习者证据；
- 不声称 WCAG、EPUB Accessibility、PDF/UA、人工辅助技术或跨平台可复现通过；
- 不把缓存路径、缓存位置摘要或 pnpm 启动快照冒充内容冻结证明；
- 不把 AI 视觉抽查冒充人工版式审查；
- 不把来源存在或 URL 可达性冒充内容真理；
- 不根据文件存在、AI 生成代码或一次绿灯推断用户已经掌握；
- 不修改真实学习时长、成绩、完成日期、求职记录或工作经历。

## 收口判定

机器侧已形成清晰、可追溯且 fail-closed 的基线；内部教材候选可以用于开始学习和后续人工审查。正式 P9 仍为 `incomplete`，直到上述人工、独立与 251 章 final manifest 门真实关闭。这个结论是本报告的最终边界，不再使用容易误解的 `PASS_WITH_FOLLOW_UP` 表述。
