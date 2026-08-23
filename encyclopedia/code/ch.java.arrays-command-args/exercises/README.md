# 公开独立练习：工单优先级批次

关闭 AI，限时 30 分钟。起始代码能编译并在空参数、`3 4 5 4` 两组输入下退出，但四处 TODO 违反数组契约：漏转第一个参数、空数组最大值含义错误、紧急边界漏掉 4、查找返回最后一个 4。

正确输出：

```text
# 无参数
count=0
max=NONE
urgent=0
first4=-1

# 参数 3 4 5 4
count=4
max=5
urgent=3
first4=1
```

运行：

```bash
cd exercises/encyclopedia/ch.java.arrays-command-args
./verify.sh
```

未修改的固定起始代码会显示 `mode=starter-pending`；四个契约全部修复后显示 `mode=solved`；任何其他输出都会非零失败。变更练习：把目标从“第一个 4”改为“最后一个 4”，先写新 oracle=3，再移动或删除 break。故障练习：临时用 `<= length`，记录异常中的 index 与 length 后恢复。
