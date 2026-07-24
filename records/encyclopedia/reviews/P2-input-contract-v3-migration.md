# P2 输入契约 schema v3 迁移说明

## 目标与范围

本迁移把 P2 五文件的单一输入摘要改成可审计的三类输入合同，关闭公共工件递归收集、
分类职责混淆和摘要无法按类别定位的问题。输出文件集合仍固定为：

- `README.md`
- `catalog.json`
- `navigation.json`
- `publication-manifest.json`
- `search-index.json`

范围包括 P2 builder/validator、生成文件 schema、公共工件 manifest 绑定、P3 baseline
消费端与对应回归测试。P8 没有直接读取 P2 manifest，因此没有人为增加新的 P2 依赖。

## v3 合同

输入集合按固定顺序划分为 `content`、`audit_security`、`build_control`，三个集合必须
互斥并完整覆盖权威输入清单。每个文件记录 `sha256(bytes)`；分类摘要为：

```text
sha256(path + NUL + content_sha256 + NUL ...)
```

其中路径按字典序排列。总摘要为：

```text
sha256(category + NUL + category_digest + NUL ...)
```

其中类别严格按 `content`、`audit_security`、`build_control` 排列。manifest 同时记录
算法 ID、三类计数和总计数；其余三个 JSON 文件复制同一组 `input_digests`。四个非
manifest 输出另有逐文件 SHA-256，避免 manifest 自引用。

`review`/`verified` 章节必须把 examples、labs、exercises 分别声明为唯一 canonical
managed root，并提供 `publication/manifests/public-artifacts/<chapter-id>.yml`。逐章
manifest 的 artifacts 与 repository metadata 并集必须和三个 managed root 的普通
文件精确相等。符号链接、未跟踪文件、未声明文件、缺失文件、大小写碰撞以及缓存、
日志和临时文件都会失败。

## 破坏性影响与迁移方式

- 删除旧 `input_digest`，不保留别名、fallback 或 schema v2/v3 双读；
- P2 runtime `schema_version` 从 2 升为 3，站点配置仍是独立的 schema v2；
- P3 plan 的 `p2_baseline` 改为固定 v3 manifest schema、算法、分类摘要和分类计数；
- 五个 P2 文件名不变，但文件内容与摘要必然变化；
- 所有新增 canonical 输入必须先进入 Git index，才能生成权威 P2 输出。

迁移顺序是：先同时更新 schema、validator、builder、P3 consumer 与测试；再生成 P2
五文件；随后重建 P3 plan/输出；最后运行各自的非变异 `--check`。禁止先发布任一侧的
半套合同。

## 回滚

回滚是原子合同回滚，不支持只恢复旧 JSON：

1. 同时恢复 P2 schema、validator、builder、P3 baseline consumer 和测试；
2. 从同一迁移前版本重新生成五个 P2 文件；
3. 重新生成依赖 P2 manifest SHA 的 P3 plan 与实体输出；
4. 依次运行 curriculum check、encyclopedia validator、P2 build/check、P3 plan/check
   与 P3 输出检查，确认没有 v2/v3 混合字节。

回滚困难度为中等：文件名没有改变，但摘要和 consumer contract 同时改变；只回滚生成
文件或只回滚代码都会 fail-closed。

## 明确非目标

本迁移不修改课程内容、48 周切片、FactoryCare 阶段门、章节状态、私有 Runner、P3
实体输出验证器、无障碍/链接工具或学习进度。机器合同通过也不构成人工教学质量、
零基础试读、无障碍合规、正式发布或人类复核证据。
