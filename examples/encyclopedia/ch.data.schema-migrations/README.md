# Schema migration 可重放示例

目录提供 V1、V2 expand、V2.1 backfill、V2.2 validate、V3 contract 和可替换报表视图。`manifest.json` 固定文件 checksum，`paths.json` 固定空库与 V1 升级库的最终 schema/data 指纹。

执行 `./verify.sh` 只验证离线迁移合同、历史不可改写和第二次 migrate 无副作用；不运行 Flyway/PostgreSQL，也不证明真实 DDL 锁与 history 状态。
