# SELECT 行集独立练习（红色 starter）

修复 `answer.sql`，使它：

- 显式投影 `id/category/created_at`；
- 只查询 schema-qualified 的设备关系；
- 正确处理启用条件和 NULL 退役时刻；
- 用括号固定 AND/OR 分组；
- 以 `created_at, device_id` 形成全序；
- 提供 offset 0 与 2 的两页。

初始文件故意使用 `= NULL`、缺少括号并只按非唯一时间排序。运行 `./verify.sh` 时，starter 被拒绝才算练习夹具正常；完成答案应交给同目录 `oracle.rb answer.sql` 验证。
