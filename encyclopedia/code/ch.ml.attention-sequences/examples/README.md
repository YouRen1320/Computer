# 三 token 缩放点积注意力

固定 `Q/K/V` 来自教材的三 token 手算例。验证会比较缩放分数、逐行 Softmax、每行和与最终加权输出。

```bash
./verify.sh
```

这里没有训练、分词器、PyTorch 或 GPU，也没有把注意力权重解释成现实因果关系。
