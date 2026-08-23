# 独立练习：修复认证与权限边界

故障源代码会接受外部 return URL、在 bootstrap 前乐观显示敏感 UI、让直接 API 信任客户端布尔值，并把 403 错当会话过期。只修 `src/auth-policy.mjs`，不要修改检查器或红灯快照。

公开 starter 应由 `./verify.sh` 稳定列出四个错误并以 41 退出；正确答案由同一命令以 0 退出并输出 `EXERCISE_GREEN`；部分修改、未知失败或基础设施异常以 43 退出。真实身份系统与 RBAC 不在离线修复范围内。
