# JavaScript 运行时与 ESM：最小绿色示例

这个目录演示一个无第三方依赖的双模块 ESM 项目。`src/status-label.mjs` 提供固定的 FactoryCare 展示值，`src/main.mjs` 负责导入并产生可比较的 stdout。

运行：

```sh
./verify.sh
```

局部验证要求 Node 22 以上，因为同一脚本要能在当前学习环境复跑；教材正式目标仍是 Node 24.x LTS 与 pnpm 11.x，须另行保存工具路径、完整版本和冻结安装证据。示例标签不是后端状态机权威。
