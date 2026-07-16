# 实验：区分连接、客户端文件和服务器 SQL 故障

该实验完全离线，不运行 `psql`。它把连接计划、成功/故障脚本、导入导出契约和固定 transcript 交给 oracle，验证：

- 显式合成本地目标和安全 flags；
- 正常脚本只读且事务边界完整；
- 故障脚本在事务中间出现固定语法错误；
- wrong database、missing file、SQL syntax 分别属于连接、客户端和服务器阶段；
- `\copy` 计划使用客户端文件、显式列、CSV header 与 NULL 标记，禁止 `PROGRAM`。

先完成 `worksheet.md`，再运行 `./verify.sh`。
