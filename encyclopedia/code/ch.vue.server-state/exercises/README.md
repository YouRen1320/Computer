# 独立练习：修复服务端状态竞态

`src/query-controller.mjs` 故意让旧响应覆盖新结果、让旧请求的 error/finally 破坏新 loading，并在 dispose 后继续提交。只修源文件，不修改检查器或预期红灯。

公开 starter 应由 `./verify.sh` 稳定输出三个错误并以 41 退出；修复目标是让同一公开命令以 0 退出并输出 `EXERCISE_GREEN`。部分修改、未知失败或基础设施异常以 43 退出；内层 Node 命令的状态只是实现细节。真实网络与 Vue 仍不在此证据内。
