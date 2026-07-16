# 隔离解析：编辑器、IDE 与源码导航

完成公开实验和练习并保留原始预测后再阅读。本文件不是无 AI 考核证据。

## 实验证据

`navigation-evidence.txt` 的固定答案为：

```text
project_root=workspace
root_marker=.factorycare-root
source_definition=src/main/java/com/factorycare/navigation/WorkOrderLabel.java:5
test_reference=src/test/java/com/factorycare/navigation/WorkOrderLabelTest.java:6
generated_candidate=target/generated-sources/com/factorycare/navigation/WorkOrderLabel.java
wrong_root_marker=missing
problem_producer=javac
first_credible_location=workspace/src/test/java/com/factorycare/navigation/WorkOrderLabelTest.java:6:30
generated_action=do-not-edit
```

必须手动输入或定向复制到公开实验证据文件；不要让答案脚本直接覆盖学习成果。正确字段只能证明路径预言，现场定义/引用跳转仍需人工演示。

## A—C

仓库根用于跨模块搜索，`backend/` 与 `frontend/` 是各自构建根。运行后端应使 Maven 找到预期 `pom.xml`，运行前端应使包管理与构建工具找到 `package.json`。生产源码、测试与受控资源是规范输入；`target/classes` 和生成目录是派生输出；External Libraries 是依赖逻辑视图；个人 workspace 状态通常不共享，但以仓库政策为准。

文件搜索按名称，全文搜索按字面内容，符号搜索按语言模型。语言服务失效时用限定范围的全文搜索找候选，再结合包、import、模块与构建日志分类，不能把文本命中直接称为语义引用。

## D—F

定义跳转证明项目模型认为使用点关联某个声明或候选；接口、多态、反射和动态加载使实际运行实现需要测试或调试证据。Problems 与 Maven 可能读取不同状态：未保存缓冲区会令 IDE 先报错而磁盘构建仍成功；反过来 IDE 索引不完整也可能漏掉真实 testCompile 错误。

运行配置至少固定入口、cwd、两类参数、允许环境、JDK/模块和前置构建。单文件运行不自动拥有 Maven 解析的依赖与资源。

## G—I

`target/generated-sources` 的完整路径就是首个边界证据。应追溯生成输入或 `src/main` 规范源码，修改后重新生成、编译并运行固定测试。保存异常按缓冲区→磁盘编码/换行→格式化器→生成器→diff 顺序核查。

符号改名先查语义引用，再用全文搜索补充文档与动态字符串。生成物不手改；前端同名规则是否同轮修改由 API 合同决定，不能只因名称相同就混改。

## J

陌生扩展和脚本可执行代码，信任 workspace 会扩大权限，完整环境可能含 Token。先只读审查来源、任务、构建文件与扩展发布者；使用固定无秘密输入和临时目录；日志只保留必要字段。若秘密已经暴露，立即按提供方流程撤销或轮换，而不是仅删除截图。
