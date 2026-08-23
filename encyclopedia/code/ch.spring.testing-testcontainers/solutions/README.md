# 私有参考解：修复“假集成测试”

参考解让 fixture 初始化临时关系库并返回真正执行参数化 SQL 的 JDBC adapter。`./verify.sh` 固定验证 2 个测试全绿。这里不声称已验证 PostgreSQL 方言；该证据属于公开 lab。
