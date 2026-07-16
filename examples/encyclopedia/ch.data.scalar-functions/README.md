# 标量函数逐行报告：正确示例

该示例不连接数据库。`query.sql` 保存 PostgreSQL 18 目标查询；`oracle.rb` 只检查任务结构，再用 Ruby 标准库对四行固定 ASCII/`numeric`/`+08:00` 夹具生成独立报告。

运行 `./verify.sh`。PASS 证明输入、操作名、输出和行数预言可重复，不证明真实 PostgreSQL 的 overload、locale 或 IANA 时区结果。
