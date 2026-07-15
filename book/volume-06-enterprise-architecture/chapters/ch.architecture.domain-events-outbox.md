---
schema_version: 2
edition: 2026.2-draft
id: ch.architecture.domain-events-outbox
title: 领域事件、Outbox 与提交一致性
responsibility: 教授在同一数据库事务记录待投递事实，不把 Outbox 当作消息必达或全局顺序保证
volume: '06'
order: 16
level: L2+
status: planned
path: book/volume-06-enterprise-architecture/chapters/ch.architecture.domain-events-outbox.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.architecture.idempotency-concurrency
version_surfaces:
- spring-boot-4.1
- postgresql-18
- mybatis
- testcontainers
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 3d78d50b4a3d66be38b66ddea03bb5518a93c8958e8a8930cf4f419a0c764119
---
<!-- GENERATED: factorycare-planned-placeholder; safe-to-overwrite: planned-only -->
# 领域事件、Outbox 与提交一致性

> 架构占位：本文件尚未包含教材正文，不能作为学习或考核完成证据。

- 语义 ID：`ch.architecture.domain-events-outbox`
- 唯一职责：教授在同一数据库事务记录待投递事实，不把 Outbox 当作消息必达或全局顺序保证
- 规范输入摘要：`3d78d50b4a3d66be38b66ddea03bb5518a93c8958e8a8930cf4f419a0c764119`
