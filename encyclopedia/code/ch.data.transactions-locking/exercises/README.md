# 练习：修复死锁与重试协议
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

当前 `answer.json` 是故意失败的 starter。执行 `./verify.sh` 应得到 `EXPECTED_RED`；第一处错误是 A、B 以相反顺序锁定 W-42/W-43。

修复要求：统一升序锁定；按 SQLSTATE 识别 `40P01` 与 `40001`；失败后先回滚再从 BEGIN 重试完整事务；限制尝试次数；保留稳定 `command_id=C-100`，并证明两次尝试只留下一个 history 和每行一次版本增长。
