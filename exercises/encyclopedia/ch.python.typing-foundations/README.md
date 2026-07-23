# 练习：修复联合、容器和返回合同

`typed_summary.py` 故意在三个边界违反类型合同：未收窄 None、向 `list[int]` 放入 str、声明返回 int 却返回字符串。

运行 `./verify.sh` 前先预测每个诊断所在行。公开初始版本必须稳定失败；目标是修复实现和真实合同，不是扩大为 Any、添加 ignore 或把所有返回改成 object。
