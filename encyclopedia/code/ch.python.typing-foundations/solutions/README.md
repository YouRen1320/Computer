# 私有参考解：收窄并保持精确合同

参考解对 None 提前返回、只向 `list[int]` 加整数，并让 `count_active` 返回真正的 int。验证器运行固定 mypy strict，也执行行为断言，避免“静态绿但结果错”。
