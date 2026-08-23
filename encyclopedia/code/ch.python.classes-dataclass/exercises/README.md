# 公开练习：维护建议对象不变量

补全 `PrioritySuggestion.__post_init__`：ID 必须以 `WO-` 开头，level 必须在 1..5。初始实现接受非法值，因此 `./verify.sh` 固定失败。
