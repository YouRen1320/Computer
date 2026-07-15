---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.config-secrets-supply-chain
title: 配置、密钥、依赖、SBOM 与供应链
responsibility: 分离代码、非敏感配置与密钥，校验依赖来源和 SBOM，建立轮换与泄漏响应，不把任何 secret 写入镜像、仓库或日志。
volume: '15'
order: 8
level: L3
status: planned
path: book/volume-15-production-factorycare/chapters/ch.ops.config-secrets-supply-chain.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.docker-production
- ch.release.ci-quality
- ch.security.untrusted-input-xss-ssrf
version_surfaces:
- ci
- git
- docker
- ubuntu-server-26.04
route_tags:
- zero-base
- accelerated-48
- reference
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 4f2cb2e123c34f305e8558e336fae3422643da11c722e1246b92aff3bd0864d3
---
<!-- GENERATED: factorycare-planned-placeholder; safe-to-overwrite: planned-only -->
# 配置、密钥、依赖、SBOM 与供应链

> 架构占位：本文件尚未包含教材正文，不能作为学习或考核完成证据。

- 语义 ID：`ch.ops.config-secrets-supply-chain`
- 唯一职责：分离代码、非敏感配置与密钥，校验依赖来源和 SBOM，建立轮换与泄漏响应，不把任何 secret 写入镜像、仓库或日志。
- 规范输入摘要：`4f2cb2e123c34f305e8558e336fae3422643da11c722e1246b92aff3bd0864d3`
