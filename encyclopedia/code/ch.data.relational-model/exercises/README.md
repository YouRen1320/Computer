# 练习：修正设备—工单关系答案
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

`answer.json` 是故意错误的 starter。只修改该文件，使其表达：

1. 工单行的唯一语义；
2. 设备与工单的稳定主键；
3. 外键从工单指向设备；
4. 设备 1 对 0..N 工单；
5. `resolved_at = NULL` 的含义与空字符串不同。

初始运行：

```sh
./verify.sh
```

应输出 `EXPECTED_RED` 且脚本自身退出 41，证明红灯被正确分类，而不是把错误 starter 冒充完成；修正后同一命令应输出 `EXERCISE_GREEN` 并退出 0。
