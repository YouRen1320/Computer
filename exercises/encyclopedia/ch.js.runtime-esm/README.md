# 练习：修复 ESM 项目合同

公开练习按设计保持红灯。不要改 `verify.sh` 或 `expected.stdout`；依次完成：

1. 把 `package.json` 中的包类型改为 ESM；
2. 让 `src/main.js` 使用带 `.js` 扩展名的相对说明符；
3. 让入口导入并输出 `statusLabel` 这一真实命名导出；
4. 运行 `./verify.sh`，确保 stdout 逐字匹配、stderr 为空、退出码为 0。

初始稳定失败标记应为 `RUNTIME_ESM_EXERCISE_RED: PACKAGE_TYPE_NOT_MODULE`。不要通过放宽比较、删除输出或改成 `.mjs` 绕过本题的 `package.json` 学习目标。
