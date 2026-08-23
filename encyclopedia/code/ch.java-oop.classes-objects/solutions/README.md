# 私有解析：定义并操作两个设备实例

只在公开练习留下独立尝试和故障证据后阅读。

修复的核心不是删除同名参数，而是明确接收者：`this.status`、`this.repairCount`、`this.code` 都是当前实例的字段；右侧参数和局部表达式只是本次调用的输入。`pump` 与 `sensor` 调用相同方法，但 `this` 分别指向不同实例。

```bash
cd solutions-private/encyclopedia/ch.java-oop.classes-objects
./verify.sh
```

固定验证器精确要求十个断言通过。私有解析不得进入公开教材或学习者第一次练习上下文。
