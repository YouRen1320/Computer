# 私有解析：设备引用、身份与空路径

只在完成公开练习并保存第一次故障证据后阅读。

关键修复有两处：字段等值必须逐项比较，不能把引用 `==` 当作业务值相等；`missing` 必须在解引用前走显式空分支。解析保留了 `primary != peer`，因为“状态相同但身份不同”正是本章要验证的边界。

```bash
cd solutions-private/encyclopedia/ch.java-oop.references-null-identity
./verify.sh
```

验证器精确要求八个断言通过。该目录不得进入公开教材、公开搜索索引或学习者初次作答上下文。
