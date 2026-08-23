# 实验：FactoryCare 角色元数据证据链

实验声明可重复的 `@RequiresRole`，再用显式指定的编译期处理器生成 `RoleIndex`。同一轮编译还证明：`SOURCE` 注解可被处理器读取却不进入 class 文件，`CLASS` 注解进入 class 文件却不能由运行时探针读取，`RUNTIME` 注解可以读取。

```bash
cd labs/encyclopedia/ch.java-engineering.annotations-metadata
./verify.sh
```

验证器明确传入 `--processor-path` 与 `-processor`，不依赖服务发现或 IDE 隐式配置；还重放错误 `@Target`、把保留策略误设为 `SOURCE`、省略 `@Retention` 三种故障。成功末行是 `LAB PASS`。实验仅使用 JDK 25 标准工具，无网络、外部服务或真实权限系统。
