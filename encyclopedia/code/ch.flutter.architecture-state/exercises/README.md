# 公开练习：状态控制器的依赖方向

`starter/` 已经能加载数据，但 presentation 层为了提供默认构造路径，直接导入并创建了
data 层实现。请修复这个依赖倒置问题：

- domain 只声明异步读取端口，不认识 data、presentation 或 Flutter；
- data 实现端口；
- presentation 的控制器只依赖 domain 端口，并由组合根注入实现；
- 真实实现和 fake 都能替换，控制器发布不可变内容状态。

可以删除违规的默认工厂，但应保留构造器注入。运行 `./verify.sh`：初始返回 `41`，修复后
返回 `0`，编译或非预期工具失败返回 `43`。
