# Lab：声明、赋值与执行顺序故障

唯一验证入口先运行绿色状态追踪，再确认三个故障边界：

- `undeclared.mjs` 读取从未声明的标识符，必须以 ReferenceError 非零退出；
- `const-reassign.mjs` 重新赋值 `const` 绑定，必须以 TypeError 非零退出；
- `order-mismatch.mjs` 正常退出，但实际 stdout 必须与故意写错的预言不同。

运行 `./verify.sh`。Lab 绿色表示故障被正确识别，不表示故障程序本身“成功”。
