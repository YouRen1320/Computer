# 独立练习：设备停机分钟数测试

建立并解释这个最小 Maven 项目，为 `DowntimeCalculator.totalMinutes` 保留两条测试：多个停机段求和、空数组返回 0。先手算 expected，再运行 `bash verify.sh`。

独立重建时不要复制 `target/`。需要说清 `src/main/java` 与 `src/test/java` 的职责、JUnit 为什么是 test scope、`@Test` 标记什么、`assertEquals(expected, actual)` 两个位置分别是什么，以及为什么只看到 `BUILD SUCCESS` 仍要检查 Tests run。

把运行前预测写入 `submission.md` 的 `## 运行预测`，把上述职责说明写入 `## 目录与依赖职责`。公开基线故意缺少该文件，所以首次执行 `verify.sh` 应以 `EXPECTED_RED` 退出；提交证据后才会运行离线 Maven 测试。
