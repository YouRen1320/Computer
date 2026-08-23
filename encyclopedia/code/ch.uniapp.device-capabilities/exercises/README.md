# 公开独立练习：修复权限与部分提交合同

`answer.json` 故意把拒绝当成功空值、每次页面显示都请求权限，并在附件成功/工单失败时写成完成。请修复为：

- 拒绝保持 `{kind: "denied"}`，不产生位置 payload；
- 三次页面显示中只因用户动作请求一次权限；
- 附件成功、工单失败时保留 attachmentId 和 idempotencyKey，最终状态为 `commit-failed`；
- 扫码取消保持 `cancelled`；无能力定位保持 `unsupported`。

运行 `./verify.sh`，先保存预期红灯，再独立修复。
