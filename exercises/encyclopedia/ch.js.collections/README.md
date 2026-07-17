# ch.js.collections 公开练习（预期红灯）

初始运行 `./verify.sh` 应非零退出，首个稳定标记是 `INPUT_MUTATED_EXERCISE`。依次修复：

1. 不排序或原地修改借入 `input`，保留到达顺序；
2. 让每个状态组保留全部记录，消除 `DUPLICATE_KEY_LOSS_EXERCISE`；
3. 复制并合并 `metadata`，消除 `REFERENCE_ALIASING_EXERCISE`；
4. 保持 `WO-1>WO-2>WO-3` 的首次 ID 去重；
5. 不改断言、expected.stdout 或 verifier 来制造绿灯。

最终 stdout 必须精确匹配 expected.stdout。private solution 只用于独立完成后的核对。
