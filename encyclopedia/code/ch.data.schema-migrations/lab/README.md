# Schema migration 故障实验

`scenarios.json` 固定 checksum 改写、一步非空列和回填中途失败。先填写 `worksheet.md`，再执行 `./verify.sh`。

oracle 验证失败分类、未静默标成功和 forward-fix 决策；不运行真实 Flyway/PostgreSQL。
