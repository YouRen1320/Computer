# 私有参考解：结构端口

实现提供端口要求的 `get/save`，无需继承 Protocol。私有验证同时运行锁定的 mypy strict
与运行时保存/读取合同。
