# 独立练习：工单批量录入 CLI

不看私有答案，实现 `src/RepairIntakeCli.java`：

- args 恰好为 `priority description` 时使用 args；args 为空时从 stdin 读取一整行；其他参数数量返回 64。
- priority 必须是 1—5 的整数；description 去除首尾空白后不能为空。
- EOF 返回 66；数据非法返回 65；成功只向 stdout 输出 `accepted priority=<值> description=<文本>` 并返回 0。
- EOF 不重试；stderr 不混入成功结果。

先预测 `verify.sh` 的六例输出和退出码，再运行。当前公开 starter 已给出一种可运行实现，练习时请自行重写 `read` 与 `parsePriority`，不要只改期望值迎合实现。

将证据写入 `submission.md`，至少包含 `## 六例预测` 与 `## 重写说明` 两节。公开基线故意不提供该文件，因此首次运行应稳定得到 `EXPECTED_RED`；补齐证据后，脚本才会继续编译并执行六个案例。
