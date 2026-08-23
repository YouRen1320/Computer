# P9 卷 06—10 修复复核记录（2026-07-24）

- `actor_class=AI`
- `review_kind=AI-assisted-remediation-verification`
- `human_review=false`
- `human_attestation=false`
- `attestation_effect=none`
- `dod_human_gate=OPEN`
- `base_commit=6bb82f14c6c3`
- `scope=F01,F02,F03,F04 in volumes 06-10`

> 本记录是 AI 对当前工作树的独立机器复核与定向补救记录，不是独立真人内容复核，不是零基础学习者试读，不是人工无障碍/版式验收，也不是 `verification/review-attestations/` 下的 review attestation。它不能关闭 Definition of Done 的真人门，不能把章节推进到 `review`、`verified` 或公开发行状态。

## 1. 结论

| Finding | 机器复核结论 | 证据边界 |
| --- | --- | --- |
| F01：32 个公开练习完成态不可达 | **已关闭（机器范围）** | 32/32 章分别在全新临时副本复现 starter=41、私有完成态经原 public verifier=0、无语义 partial=43；没有替换 public verifier/oracle。 |
| F02：Web 首章隐藏要求从空白写 HTML/CSS/SVG/Python server | **已关闭（教材/本地脚本范围）** | 独立任务改为给定 fixture；`serve.sh` 只绑定 loopback，有端口校验、后端探测、停止说明和失败退出。真实浏览器 DevTools 证据仍未执行。 |
| F03：小程序运行时遗漏 JavaScript 对象/异步硬前置 | **canonical 输入已关闭；派生物待重建** | volume-10 规范输入、章节 front matter/前置说明和 capability 输入均加入对象模型与事件循环；编译器内存渲染结果正确。当前磁盘上的 `curriculum/concept-graph.md` 仍是旧派生物，必须由后续全局 `--write` 重建。 |
| F04：15 处公开退出码文档仍写 1 | **旧文案已清除，三态语义已对齐** | 15/15 文档均说明 public 0/41/43。复核时发现 3 个额外 wrapper 原本仍把 partial 误分类为 41，现已补精确 starter 字节身份；TS 泛型私有解的 export 缺口也已修复并复测。 |

本轮没有发现仍会阻断 F01—F04 机器闭环的章级缺陷。仍然开放的项目是全局派生物重建、真实平台验证以及全部真人门，详见第 8 节。

## 2. 环境与方法

- 主机：macOS arm64。
- Java：Temurin/OpenJDK `25.0.3`；`javac 25.0.3`。
- Node：`v22.14.0`。
- pnpm launcher：`10.18.0`；两个 TS verifier 从锁文件离线安装并断言项目内 TypeScript `7.0.2`。
- Ruby：`2.6.10p210`。
- 所有三态试验都把公开练习复制到新的 `/tmp/fc-v0610-*` 目录；仓库中已有 `build/`、`node_modules/` 和 `.verify-dist/` 不参与输入。
- starter 试验不修改任何输入；solved 试验只覆盖学习者可编辑输入；partial 试验只给第一个登记 starter 输入增加一个不改变语义的空白行，使字节摘要变化而业务失败形状保持不变。
- Java 私有文件以 `*ChallengeSolution.java` 保存。覆入公开副本时只做 `*ChallengeSolution` → `*Challenge` 的机械类名重命名，以满足 Java 文件名/公开类名规则；其余私有实现字节不改，public `verify.sh` 不改。
- Web/CSS/Vue solved 副本只覆盖 `STARTER_FILES`；`ch.web.media-assets` 还按公开 README 增加私有完成态的 `captions.vtt` 与 `transcript.html`。
- 临时目录不是发行证据仓；本报告只记录命令结果。正式机器证据仍应由全局 Runner 在修复后的精确字节上重建。

## 3. F01：32 章逐项三态实测

最终汇总：

```text
starter: SUMMARY chapters=32 expected_red_41=32 failures=0
solved:  SUMMARY chapters=32 solved_green_0=32 failures=0
partial: SUMMARY chapters=32 partial_unknown_43=32 failures=0
```

三个最终临时副本根分别为：

- `/tmp/fc-v0610-starter.wkxptw`
- `/tmp/fc-v0610-solved-complete.Qj0oTu`
- `/tmp/fc-v0610-partial.op7oFC`

| 章节 | 原始 starter | 私有完成态 + 同一 public verifier | 无语义 partial | 标记核对 |
| --- | ---: | ---: | ---: | --- |
| `ch.architecture.domain-events-outbox` | 41 | 0 | 43 | `EXPECTED_RED` / `EXERCISE_GREEN` / `EXERCISE_FAILURE_SHAPE_MISMATCH` |
| `ch.architecture.idempotency-concurrency` | 41 | 0 | 43 | 同上 |
| `ch.architecture.modular-monolith` | 41 | 0 | 43 | 同上 |
| `ch.architecture.workflow-state-sla` | 41 | 0 | 43 | 同上 |
| `ch.distributed.messaging-delivery` | 41 | 0 | 43 | 同上 |
| `ch.distributed.redis-cache-rate-limit` | 41 | 0 | 43 | 同上 |
| `ch.security.audit-events-privacy` | 41 | 0 | 43 | 同上 |
| `ch.security.authorization-rbac-abac` | 41 | 0 | 43 | 同上 |
| `ch.security.cookie-session-model` | 41 | 0 | 43 | 同上 |
| `ch.security.identity-password-lifecycle` | 41 | 0 | 43 | 同上 |
| `ch.security.jwt-resource-server` | 41 | 0 | 43 | 同上 |
| `ch.security.multitenancy-data-isolation` | 41 | 0 | 43 | 同上 |
| `ch.security.oauth2-oidc` | 41 | 0 | 43 | 同上 |
| `ch.security.origin-cors-csrf` | 41 | 0 | 43 | 同上 |
| `ch.security.session-authentication` | 41 | 0 | 43 | 同上 |
| `ch.security.spring-security-architecture` | 41 | 0 | 43 | 同上 |
| `ch.security.threat-model-trust-boundaries` | 41 | 0 | 43 | 同上 |
| `ch.security.untrusted-input-xss-ssrf` | 41 | 0 | 43 | 同上 |
| `ch.web.browser-render-devtools` | 41 | 0 | 43 | 同上 |
| `ch.web.origin-cookie-cache` | 41 | 0 | 43 | 同上 |
| `ch.web.semantic-html` | 41 | 0 | 43 | 同上 |
| `ch.web.forms-validation` | 41 | 0 | 43 | 同上 |
| `ch.web.media-assets` | 41 | 0 | 43 | 同上；完成态包含新增字幕与 transcript |
| `ch.web.accessibility-interaction` | 41 | 0 | 43 | 同上 |
| `ch.css.cascade` | 41 | 0 | 43 | 同上 |
| `ch.css.box-position` | 41 | 0 | 43 | 同上 |
| `ch.css.flexbox` | 41 | 0 | 43 | 同上 |
| `ch.css.grid` | 41 | 0 | 43 | 同上 |
| `ch.css.theme-variables` | 41 | 0 | 43 | 同上 |
| `ch.css.motion-compositing` | 41 | 0 | 43 | 同上 |
| `ch.vue.auth-permissions` | 41 | 0 | 43 | 同上 |
| `ch.vue.server-state` | 41 | 0 | 43 | 同上 |

该结果证明 public wrapper 已能区分精确登记 starter、完成态和未知/部分修改；它不证明真实 Spring、数据库、broker、浏览器或 Vue 运行时已通过。

## 4. F02：给定 Web fixture 与安全本地服务

### 4.1 教材合同

已核对 `book/volume-07-web-platform/chapters/ch.web.browser-render-devtools.md`：

- build outcome 明确使用仓库给定最小页面，不要求从空白创作尚未教授的 HTML/CSS/SVG；
- 启动步骤为 `./verify.sh` 后 `bash ./serve.sh 4173`；
- 独立任务是复制/观察给定 fixture、写预测、注入 CSS 路径 404、恢复并重跑；
- 明确本章不要求写自定义 server，完成后用 `Ctrl-C` 停止；
- 仍保留 HAR 脱敏、浏览器版本/viewport/cache 与真实 DevTools 人工证据门。

### 4.2 脚本实测

| 检查 | 结果 |
| --- | --- |
| `bash -n serve.sh` | 0 |
| `bash serve.sh --check 4173` | `STATIC_SERVER_READY bind=127.0.0.1 port=4173 ... backend=python3` |
| `bash serve.sh --check 80` | 2，`STATIC_SERVER_ERROR invalid-port=80 expected=1024..65535` |
| 实际启动端口 44173 | `lsof` 只显示 `TCP 127.0.0.1:44173 (LISTEN)` |
| `curl --fail http://127.0.0.1:44173/index.html` | 0，取得给定 FactoryCare 合成页面 |
| `examples/.../verify.sh` | 0，`BROWSER_RENDER_EXAMPLE=PASS` |

脚本还静态核对了 Python、Ruby、JDK `jwebserver` 三个后端都使用 loopback 参数。这里只真实执行了本机优先命中的 Python 后端；Ruby/JDK fallback 的真实监听仍可由跨环境 Runner 补证。

## 5. F03：小程序 JavaScript 硬前置

### 5.1 canonical 输入一致性

| 位置 | 当前合同 |
| --- | --- |
| `curriculum/chapters/volume-10.yml` | `prerequisites: [ch.js.object-model, ch.js.event-loop]`；rationale 分别绑定 `web.javascript-objects` 与 `web.javascript-async-runtime`；三个 outcome 都使用这两个 capability。 |
| `book/.../ch.miniapp.runtime.md` | front matter 前置为 `ch.js.object-model`、`ch.js.event-loop`；生成前置说明明确 App/Page 对象模型、回调/Promise/生命周期依赖。 |
| `curriculum/capabilities.yml` | `mobile.miniprogram-runtime.requires` 同时包含 `foundation.shell-command-stream`、`web.javascript-objects`、`web.javascript-async-runtime`。 |

`ruby scripts/generate-curriculum.rb --plan` 成功完成 source validation：

```text
edition=2026.2-draft chapters=255 volumes=16 capabilities=94 modules=48 factorycare_stages=8
```

直接从当前 canonical 输入调用 compiler 的内存渲染，目标图边为：

```text
| mobile.miniprogram-runtime | ch.miniapp.runtime | foundation.shell-command-stream, web.javascript-objects, web.javascript-async-runtime |
- ch.miniapp.runtime ← ch.js.object-model, ch.js.event-loop
```

### 5.2 尚未写入的派生物

当前磁盘上的 `curriculum/concept-graph.md` 仍显示旧边：

```text
mobile.miniprogram-runtime → foundation.shell-command-stream
ch.miniapp.runtime ← ch.foundations.cli-streams-exit-codes
```

`--plan` 正确把它列为 `UPDATE`。本复核按任务约束没有执行全局 `--write`；因此 F03 的 canonical 输入已修复，但导航/路线等全局派生物必须在后续统一重建后再做 `--check`。

## 6. F04：15 处文档与额外三态补救

### 6.1 文档逐项核对

下列 15 处都明确说明 public `./verify.sh` 的 `0=完成态`、`41=精确登记 starter`、`43=partial/unknown/infra`，未再把 public expected-red 写成 1：

| 文档 | 文案结果 | 行为证据 |
| --- | --- | --- |
| `ch.css.box-position/README.md` | 0/41/43 | F01 三态实测 |
| `ch.css.cascade/README.md` | 0/41/43 | F01 三态实测 |
| `ch.css.flexbox/README.md` | 0/41/43 | F01 三态实测 |
| `ch.css.grid/README.md` | 0/41/43 | F01 三态实测 |
| `ch.css.motion-compositing/README.md` | 0/41/43 | F01 三态实测 |
| `ch.css.theme-variables/README.md` | 0/41/43；明确 inner Ruby 的 1 不是 public 合同 | F01 三态实测 |
| `ch.web.accessibility-interaction/README.md` | 0/41/43 | F01 三态实测 |
| `ch.web.forms-validation/README.md` | 0/41/43 | F01 三态实测 |
| `ch.web.media-assets/README.md` | 0/41/43 | F01 三态实测 |
| `ch.web.semantic-html/README.md` | 0/41/43 | F01 三态实测 |
| `ch.ts.generics-utilities/README.md` | 0/41/43；明确仅字节一致 starter=41 | 第 6.2 节三态实测 |
| `ch.ts.modeling-narrowing/README.md` | 0/41/43；明确仅字节一致 starter=41 | 第 6.2 节三态实测 |
| `ch.vue.auth-permissions/README.md` | 0/41/43 | F01 三态实测 |
| `ch.vue.server-state/README.md` | 0/41/43 | F01 三态实测 |
| `ch.uniapp.factorycare-reporter.md` | 0/41/43 | 第 6.2 节三态实测 |

### 6.2 复核中发现并修复的 3 个残留

首次额外试验发现：

- `ch.ts.generics-utilities`、`ch.ts.modeling-narrowing`、`ch.uniapp.factorycare-reporter` 都会把只增加空白行的 partial 继续误分为 41；
- TS 泛型私有 `solution.ts` 未 export `WorkOrder` 与 `selectField`，覆入 public verifier 后独立负向 key fixture 报 TS2459，返回 43。

补救：

- 三个 public wrapper 都绑定当前 starter 输入的 SHA-256；只有精确字节 + 已登记红灯 marker 才返回 41；
- partial、未知失败、缺文件或 hash 工具缺失均 fail-closed 为 43；
- TS 泛型私有解导出 `WorkOrder` 与 `selectField`，继续由 public 独立负向 fixture 要求非法 key 产生 TS2345；
- 三份 README 明确“只有字节完全一致的登记 starter=41”。

修复后全新临时副本 `/tmp/fc-v0610-f04-fixed.3n4yQr`：

| 章节 | starter | 私有完成态 + public verifier | 无语义 partial | 三类 marker |
| --- | ---: | ---: | ---: | --- |
| `ch.ts.generics-utilities` | 41 | 0 | 43 | 全部匹配 |
| `ch.ts.modeling-narrowing` | 41 | 0 | 43 | 全部匹配 |
| `ch.uniapp.factorycare-reporter` | 41 | 0 | 43 | 全部匹配 |

三份 private 自有 `verify.sh` 也都以 0 退出。

## 7. 其他聚焦检查

| 检查 | 结果 |
| --- | --- |
| 32 个 F01 public verifier + Web `serve.sh`/example verifier 的 `bash -n` | 34/34 通过 |
| 3 个 F04 补救 wrapper 的 `bash -n` | 3/3 通过 |
| 相关路径 `git diff --check` | 通过 |
| `ruby scripts/generate-curriculum.rb --plan` | 通过 source validation；正确列出待重建派生物 |
| `PROGRESS.md` | 未修改 |

本轮没有执行 77 章全部 example/exercise/lab/private endpoint、全书 Runner、正式 HTML/EPUB/PDF 构建或全平台矩阵；这些属于父任务的全量回归阶段。

## 8. 残留门与非目标

1. **全局派生物待重建**：至少 `catalog.yml`、`concept-graph.md`、gates 与 routes 被 `--plan` 列为 `UPDATE`；本轮没有越权写入。
2. **真人复核仍为 0**：本 AI 记录不得复制成 attestation，不关闭逐章真人内容结论、零基础试读或最终发行批准。
3. **真实平台未覆盖**：Spring/PostgreSQL/Redis/broker、Chrome/Firefox/Safari、人工键盘/读屏、微信开发者工具/真机均未由本轮复核。
4. **出版门未覆盖**：未人工检查 HTML/EPUB/PDF 的分页、阅读顺序、代码块、表格、字体和辅助技术互操作。
5. **没有进度宣称**：未修改 `PROGRESS.md`，未推断学习小时、分数或章节掌握状态。

## 9. 兼容性说明

- public wrapper 的长期合同现在统一为 0/41/43；inner compiler/oracle 的退出 1 仍可作为内部实现细节，但不再对外冒充 public 合同。
- 三个 F04 wrapper 不再兼容“任意带登记 marker 的失败都算 expected-red”的宽松旧行为；这是刻意的 fail-closed 收紧，使 partial/未知失败可被识别。
- 没有为旧错误分类增加兼容分支，也没有削弱任何负向 fixture。
