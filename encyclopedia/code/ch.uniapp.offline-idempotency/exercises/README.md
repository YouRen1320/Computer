# 公开独立练习：修复重放合同

同一 commandId 的所有 replay 必须复用一个 key；有限 attempt 并有 next time/dead-letter；401 阻塞认证、409 冲突、毒消息隔离；切换用户/环境不可发送。
