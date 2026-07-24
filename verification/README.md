# 章级可复现验证合同

本目录实现 P9 D5 的自动化部分。当前覆盖四个 Java 黄金样章，共 12 个独立 recipe；它不是 255 章已经完成验证的声明。

## 合同边界

- `manifests/<chapter-id>.yml` 逐文件声明公共输入、SHA-256、模式、工具版本、固定命令、精确退出码、可观察预言和完整输出增量。
- evidence 同时锁定 schema、固定 CLI 与 Runner/路径/原子写入实现的控制面摘要，避免只锁教材输入却遗漏验证器版本。
- 每个 recipe 都复制到独立系统临时目录。Runner 不从 manifest 接受任意解释器、绝对路径或 shell 命令字符串。
- `solutions-private/`、`sources/private/`、符号链接、路径穿越、大小写冲突、输入漂移、输入修改和未声明输出都会失败。
- 命令的 stdout/stderr 原文不会写入 evidence；临时 sandbox 前缀、其中随机命名的 `tmp` 子项以及携带临时时间戳的绝对 diff 头先统一替换为占位符，证据再保存规范化摘要、大小、通过的观察数量和公共相对路径。该规则支持同机固定工具环境的重复证据字节，不等同跨平台可复现。
- 只有全部 recipe 通过后，`verification/evidence/last-run/evidence.json` 才会通过 staging 与 rename 原子替换。失败保留上一份成功证据。
- 这是干净副本和 fail-closed 清单，不是容器或 OS 沙箱。网络策略与仓库外文件系统并未由操作系统强制隔离，因此不能把结果称为供应链安全、跨平台可复现、无障碍合规或人工教学审查通过。

## 使用

只校验 schema、语义、文件模式和输入摘要，不执行教学代码：

```bash
ruby scripts/run-verification.rb --check
```

真实执行所有已有 manifest 并原子写入最后一次成功证据：

```bash
ruby scripts/run-verification.rb
```

机器可读摘要可追加 `--json`。摘要不会包含命令原始输出或本机临时路径。

要求 255 章全部具备最终 manifest 时使用硬门；当前会按设计返回非零：

```bash
ruby scripts/run-verification.rb --check --require-complete
ruby scripts/generate-verification-manifests.rb --coverage --json
```

第二条命令会给出每个缺口 ID、已有最终合同数、bootstrap candidate 数、候选入口总数与静态工具提示统计。生成逐章候选清单但不写成最终合同：

```bash
ruby scripts/generate-verification-manifests.rb --bootstrap-candidates --json
```

输入文件经过有意修改后，先人工复核 recipe 合同，再刷新已有 manifest 的模式和摘要：

```bash
ruby scripts/generate-verification-manifests.rb --write
ruby scripts/generate-verification-manifests.rb --check
```

生成器刻意不推断命令、退出码、观察或输出集合。自动猜测这些字段会把未知行为误写成已验证合同。扩展到剩余 251 章时，应先逐章确认唯一 `verify.sh` 入口、公开练习的稳定 expected-red、工具版本及真实文件系统增量，再运行摘要刷新和统一 Runner。

## 当前未验证

- 其余 251 章还没有 D5 final manifest；覆盖硬门会逐章报告而不是静默放行；
- 私有答案不进入公共 manifest，也没有由本框架保存成可分发证据；
- Linux、Windows、其他 JDK/工具 patch 与网络断开环境未执行；
- HTML、EPUB、PDF 的人工版式、键盘、读屏和零基础读者任务不属于本 Runner。
