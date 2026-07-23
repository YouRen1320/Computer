# 公开练习：去掉不安全的 `!`

入口把可空的处理人姓名直接用 `!` 强制解包。分析器允许这条由程序员作出的断言，
但当前输入为 `null`，所以运行时应失败。请改为可说明业务语义的空感知处理，并让输出为：

```text
DART_TYPES_EXERCISE_PASS assignee=UNASSIGNED
```

公开版本的 `./verify.sh` 是稳定预期红。
