# 实验：注意力 mask 与 Transformer 形状流

实验在手算矩阵上增加 causal mask，并检查被禁止权重为零、每个 query 的有效权重和为一、全遮蔽输入被明确拒绝。`block_shape_trace` 给出多头注意力、拼接、输出投影、残差和 FFN 的形状账本。

```bash
./verify.sh
```

该形状流不是已训练 Transformer，也没有验证 PyTorch 高性能内核、GPU、长上下文或注意力解释。
