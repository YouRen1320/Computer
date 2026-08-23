# ch.js.collections 私有参考解

仅在独立修复公开练习后核对。参考解把借入输入保持只读，分组保留全部快照与首次状态顺序，`Set` 对字符串 ID 去重，并为每个输出记录及 `metadata` 建立新引用。运行 `./verify.sh` 应零退出并精确匹配 stdout。
