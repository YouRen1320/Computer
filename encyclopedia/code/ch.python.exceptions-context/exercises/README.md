# 练习：不要让 `__exit__` 吞异常

公开 manager 无条件返回 True，使 with 块中的 RuntimeError 被抑制。修复为 False/None，并确认 cleanup 仍执行一次。初始验证必须失败。
