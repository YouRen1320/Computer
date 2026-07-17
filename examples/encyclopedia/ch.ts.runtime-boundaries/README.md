# TypeScript 运行时边界示例

该示例使用 Zod 4.4.3、TypeScript 7.0.2 与 Vitest 4.1.10，验证合法负载收窄、缺失/额外/错误类型负载稳定失败，以及格式、policy lint、typecheck、测试和 build 的 fail-fast 顺序。

```bash
./verify.sh
```

本地若不是 Node 24/pnpm 11，只能算兼容性探测，不代表 canonical 目标矩阵已经验证。

