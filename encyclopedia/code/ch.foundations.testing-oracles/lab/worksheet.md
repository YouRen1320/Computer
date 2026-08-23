# 测试预言实验记录：expected 必须先写

| case | Arrange 输入 | expected/expected error | Act | actual | Assert 结果 |
| --- | --- | --- | --- | --- | --- |
| normal-two-blocks | 60, 5000, 1000 |  | quote |  |  |
| zero-labor-keeps-parts | 0, 5000, 1250 |  | quote |  |  |
| one-minute-starts-one-block | 1, 5000, 0 |  | quote |  |  |
| thirty-minutes-is-one-block | 30, 5000, 0 |  | quote |  |  |
| thirty-one-minutes-starts-two-blocks | 31, 5000, 0 |  | quote |  |  |
| maximum-labor-boundary | 1440, 100, 0 |  | quote |  |  |
| negative-labor-is-invalid | -1, 5000, 0 |  | quote |  |  |
| string-minutes-is-invalid | "30", 5000, 0 |  | quote |  |  |

## 三次运行

| 阶段 | 命令 | Tests run | Failures | Errors | exit | 是否符合预言 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 初始绿 |  |  |  |  |  |  |
| 注入红 |  |  |  |  |  |  |
| 恢复绿 |  |  |  |  |  |  |

## 首个可信证据

- 第一条失败 case：
- expected：
- actual：
- 指向的规则：
- 不能由该行推出的结论：

## 层级边界

- 当前 T 层级与理由：
- 未执行的 T2/T3/T4：
- 需要进入更高层才可回答的问题：
