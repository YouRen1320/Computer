---
schema_version: 2
edition: 2026.2-draft
id: ch.llm.tool-calling
title: 工具调用、参数验证与信任边界
responsibility: 把模型提出的工具意图视为不可信输入，经白名单、Schema、授权和人工确认后执行，隔离读操作与高风险副作用。
volume: '14'
order: 5
level: L3
status: planned
path: book/volume-14-llm-rag-agents/chapters/ch.llm.tool-calling.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.llm.structured-output
- ch.llm.streaming-resilience
- ch.security.untrusted-input-xss-ssrf
version_surfaces:
- python-3.14
- model-api
- pydantic-2
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 484dc13aaa64bcfd630992b49a5ab9be88645640e312b5617c02439ca35731dc
---
<!-- GENERATED: factorycare-planned-placeholder; safe-to-overwrite: planned-only -->
# 工具调用、参数验证与信任边界

> 架构占位：本文件尚未包含教材正文，不能作为学习或考核完成证据。

- 语义 ID：`ch.llm.tool-calling`
- 唯一职责：把模型提出的工具意图视为不可信输入，经白名单、Schema、授权和人工确认后执行，隔离读操作与高风险副作用。
- 规范输入摘要：`484dc13aaa64bcfd630992b49a5ab9be88645640e312b5617c02439ca35731dc`
