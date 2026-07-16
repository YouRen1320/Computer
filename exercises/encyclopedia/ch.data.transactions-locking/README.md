# 练习：修复死锁与重试协议

当前 `answer.json` 是故意失败的 starter。执行 `./verify.sh` 应得到 `EXPECTED_RED`；第一处错误是 A、B 以相反顺序锁定 W-42/W-43。

修复要求：统一升序锁定；按 SQLSTATE 识别 `40P01` 与 `40001`；失败后先回滚再从 BEGIN 重试完整事务；限制尝试次数；保留稳定 `command_id=C-100`，并证明两次尝试只留下一个 history 和每行一次版本增长。
