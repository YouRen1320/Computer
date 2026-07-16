# 公开独立练习：FactoryCare 工单方法拆分

关闭 AI，限时 35 分钟。起始代码能编译并终止，但四个 TODO 分别违反方法公式、同类型参数顺序、数组参数副作用和递归基线。

正确输出：

```text
total=5997
remaining=7
first=5
countdown=4
```

```bash
cd exercises/encyclopedia/ch.java.methods
./verify.sh
```

固定起始代码显示 `mode=starter-pending`；正确完成后显示 `mode=solved`；其他输出非零失败。修复时先分别写四个方法契约，不改变输出格式。变更练习：把 countdown 输入从 4 改为 5，先画 5→4→3→2→1→0，再改 oracle。
