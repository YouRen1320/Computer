---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.offline-idempotency
title: 离线队列、重试、冲突与幂等重放
responsibility: 为离线报修定义持久队列、幂等键、有限重试和冲突决策，保证重放不重复创建且失败可观察，不把缓存等同离线同步。
volume: '10'
order: 9
level: L3
status: planned
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.offline-idempotency.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.platform-conditional
- ch.uniapp.packages-performance
- ch.architecture.idempotency-concurrency
version_surfaces:
- uni-app
- wechat-miniprogram
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 5b4a9185a4a7dfddca95b27d96a3c34b3228b19100575644ce02188877d47c8e
---
<!-- GENERATED: factorycare-planned-placeholder; safe-to-overwrite: planned-only -->
# 离线队列、重试、冲突与幂等重放

> 架构占位：本文件尚未包含教材正文，不能作为学习或考核完成证据。

- 语义 ID：`ch.uniapp.offline-idempotency`
- 唯一职责：为离线报修定义持久队列、幂等键、有限重试和冲突决策，保证重放不重复创建且失败可观察，不把缓存等同离线同步。
- 规范输入摘要：`5b4a9185a4a7dfddca95b27d96a3c34b3228b19100575644ce02188877d47c8e`
