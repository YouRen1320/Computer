# 独立练习：修复服务端状态竞态

`src/query-controller.mjs` 故意让旧响应覆盖新结果、让旧请求的 error/finally 破坏新 loading，并在 dispose 后继续提交。只修源文件，不修改检查器或预期红灯。

公开 `./verify.sh` 应稳定输出三个错误并以 `1` 退出。修复目标是让 `node scripts/check-contract.mjs` 变绿；真实网络与 Vue 仍不在此证据内。
