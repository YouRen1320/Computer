# 私有参考：Composable 所有权修复

该目录只用于作者验证。它把状态移入函数、为每轮 repository 调用登记 AbortController cleanup，并只公开 readonly refs 与命令。运行 `./verify.sh` 应转绿；学习者不得把本目录当作独立完成证据。
